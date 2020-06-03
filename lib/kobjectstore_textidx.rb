# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



# TODO: Test what happens with indexed text when an object is deleted in object store tests
# TODO: Check actual contents of Xapian indicies for objects (checking fields, qualifiers, non-stemmed terms, etc)
# TODO: There's lots of language boundary crossing and text conversions. Could be turned into Java code which does it more efficiently.

# PERM TODO: Add in label support for text index writing in kobjectstore_textidx.rb, or write up properly why it's not required. (could be adding in labels for efficiency in text searching)

class KXapianWriter
  def initialize(pathname_full, pathname_fields)
    @pathname_full = pathname_full
    @pathname_fields = pathname_fields
    @documents = []
    @to_delete = []
  end

  def document(docid)
    doc = Document.new(docid)
    @documents << doc
    doc
  end

  def delete_document(docid)
    @to_delete.push(docid)
  end

  class Document
    def initialize(docid)
      @docid = docid
      @terms = []
    end
    def post_terms(terms, restriction_labels, prefix1, prefix2, weight)
      restriction_labels_str = restriction_labels.map { |l| KObjRef.new(l.to_i).to_presentation } .join(',')
      @terms << [terms, restriction_labels_str, prefix1, prefix2, weight]
    end
    def _write(handle, pg)
      pg.exec("SELECT oxp_w_start_document($1)", handle)
      term_position = 1 # Position starts at 1 for Xapian terms - http://xapian.org/docs/quickstart.html ("preparing the document")
      @terms.each do |terms, restriction_labels_str, prefix1, prefix2, weight|
        term_position = pg.exec("SELECT oxp_w_post_terms($1,$2,$3,$4,$5,$6,$7)", handle, terms, restriction_labels_str, prefix1, prefix2, term_position, weight).first.first.to_i
      end
      pg.exec("SELECT oxp_w_finish_document($1,$2)", handle, @docid)
    end
  end

  def write
    KApp.with_pg_database do |pg|
      handle = pg.exec("SELECT oxp_w_open($1,$2)", @pathname_full, @pathname_fields).first.first.to_i
      begin
        pg.exec("SELECT oxp_w_start_transaction($1)", handle)
        begin
          @documents.each do |document|
            document._write(handle, pg)
          end
          @to_delete.each do |docid|
            begin
              pg.exec("SELECT oxp_w_delete_document($1,$2)", handle, docid)
            rescue => e
              KApp.logger.error "Failed to delete document #{docid} from Xapian index, error #{e.inspect}"
            end
          end
        ensure
          pg.exec("SELECT oxp_w_commit_transaction($1)", handle)
        end
      ensure
        pg.exec("SELECT oxp_w_close($1)", handle)
      end
    end
  end

end


class KObjectStore

  # What indicies need to be initialised on disc in app init?
  TEXT_INDEX_FOR_INIT = [:full, :fields]

  # Don't do too many objects for an app before moving to another one - give everything a fair chance
  TEXT_INDEX_MAX_PER_APP = 16

  # How many items to reindex at once in a reindex process
  TEXT_INDEX_MAX_REINDEX = 16

  # The app ID of an index to close
  @@reindex_close_app = nil

  # Maximum number of parent links to follow when including terms from linked objects
  TEXT_INDEX_MAX_PARENT_COUNT = 128

  # --------------------------------------------------------------------------------------------------------------------

  def self.run_text_indexing
    @@textidx_do_indexing_flag = true

    while @@textidx_do_indexing_flag
      do_reindex_close_app() if @@reindex_close_app != nil
      unless do_text_indexing()
        # Wait on flag for next job (triggered for dirty object or reindex)
        TEXTIDX_FLAG.waitForFlag(600000)  # 600 seconds = 5 minutes
      end
    end
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.stop_text_indexing
    @@textidx_do_indexing_flag = false
    TEXTIDX_FLAG.setFlag()
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.do_reindex_close_app
    KApp.with_pg_database do |pg|
      # Make sure text indexing is finished and closed for an app
      pg.perform("DELETE FROM public.os_store_reindex WHERE app_id=$1", @@reindex_close_app)
      pg.perform("DELETE FROM public.os_dirty_text WHERE app_id=$1", @@reindex_close_app)
    end
    # And unflag the pending closure
    @@reindex_close_app = nil
  end

  # --------------------------------------------------------------------------------------------------------------------

  def self.do_text_indexing
    done_something = false

    applications_requiring_work = []
    KApp.with_pg_database do |db|
      [
        'SELECT DISTINCT app_id FROM public.os_dirty_text ORDER BY app_id',
        'SELECT DISTINCT app_id FROM public.os_store_reindex ORDER BY app_id'
      ].each do |sql|
        applications_requiring_work.concat(
          db.exec(sql).map { |r| r.first.to_i }
        )
      end
    end
    applications_requiring_work.uniq!

    applications_requiring_work.each do |app_id|
      work = StoreReindexWork.new(app_id)
      if work.prepare
        done_something = true 
        work.perform
      end
    end

    done_something
  end

  # --------------------------------------------------------------------------------------------------------------------

  class StoreReindexWork
    include KConstants

    def initialize(app_id)
      @app_id = app_id
    end

    def prepare
      work_to_do = false
      @dirty_objects = []
      KApp.with_pg_database do |db|
        # The os_dirty_text table will, most of the time, contain only a few objects for only one application.
        # However, occasionally, it'll contain lots of objects when an object which has many other objects linking
        # to it is modified. In this case, we want to avoid 1) loading all the rows every time and 2) letting
        # one application hog the indexing process.
        #
        # There is no index on the os_dirty_text table, because it's probably not necessary. It may require
        # the odd table scan, but it's only happening in one connection.
        #
        # Don't use ordering on any of the queries, so postgres can just pick off the first rows in a table scan
        # and doesn't need to do sorting.

        # no ORDER BY clause in the query, to avoid unnecessary sorting
        sql = "SELECT id,osobj_id FROM public.os_dirty_text WHERE app_id=#{@app_id} LIMIT #{KObjectStore::TEXT_INDEX_MAX_PER_APP}"
        db.exec(sql).each do |row_id,osobj_id|
          @dirty_objects << [row_id.to_i,osobj_id.to_i]
        end
        work_to_do = true unless @dirty_objects.empty?

        sql = "SELECT id,filter_by_attr,progress FROM public.os_store_reindex WHERE app_id=#{@app_id} ORDER BY id LIMIT 1"
        reindex_q = db.exec(sql)
        if reindex_q.length > 0
          rid,rfilter,rprogress = reindex_q.first
          @reindex_id = rid.to_i
          @reindex_filter = (rfilter == '') ? nil : (rfilter.split(',').map { |a| a.to_i })
          @reindex_progress = rprogress.to_i
          work_to_do = true
        end
      end

      work_to_do
    end

    def perform
      # Dirty objects?
      unless @dirty_objects.empty?
        KApp.in_application(@app_id) do
          do_text_indexing(@dirty_objects.map { |e| e.last })
        end

        # Delete the entries in the dirty table
        # For efficiency, use a transaction type which won't fsync to disc, but is still safe. Don't care if we redo an index.
        KApp.with_pg_database do |db|
          db.perform(%Q!BEGIN; SET LOCAL synchronous_commit TO OFF; DELETE FROM public.os_dirty_text WHERE id IN (#{@dirty_objects.map { |e| e.first } .join(',')}); COMMIT!)
        end
      end

      # Reindex in progress?
      if @reindex_id
        # Get next chunk of work
        sql = "SELECT id FROM a#{@app_id}.os_objects WHERE id>#{@reindex_progress.to_i} ORDER BY id LIMIT #{KObjectStore::TEXT_INDEX_MAX_REINDEX}"
        reindex_ids = KApp.with_pg_database do |db|
          db.exec(sql).map { |r| r.first.to_i }
        end
        if reindex_ids.empty?
          # Save the updated weightings
          KApp.in_application(@app_id) do
            File.open(KObjectStore.get_current_weightings_file_pathname_for_id(@app_id),'w') do |f|
              f.write KObjectStore.schema.attr_weightings_for_indexing_sorted.to_yaml
            end
          end
          KApp.with_pg_database do |db|
            db.perform("DELETE FROM public.os_store_reindex WHERE id=#{@reindex_id.to_i}")
          end
          KApp.logger.info("Completed reindex of application #{@app_id}")
          KApp.logger.flush_buffered
        else
          KApp.in_application(@app_id) do
            do_text_indexing(reindex_ids) do |obj|
              if @reindex_filter == nil
                # No filtering
                true
              else
                # Check to see if there's an attribute which needs to be reindexed
                needs_reindex = false
                obj.each do |v,desc,q|
                  needs_reindex = true if @reindex_filter.include?(desc)
                end
                needs_reindex
              end
            end
          end
          KApp.with_pg_database do |db|
            db.perform(%Q!BEGIN; SET LOCAL synchronous_commit TO OFF; UPDATE public.os_store_reindex SET progress=#{reindex_ids.last.to_i} WHERE id=#{@reindex_id.to_i}; COMMIT!)
          end
        end
      end
    end

    def do_text_indexing(obj_list)
      # Fetch objects from the database
      sql = %Q!SELECT id,type_object_id,object,labels FROM a#{@app_id}.os_objects WHERE id IN (#{obj_list.join(',')})!
      fetched_objs = KApp.with_pg_database { |pg| pg.exec(sql) }

      store = KObjectStore.store
      schema = store.schema
      delegate = store._delegate
      attr_weightings = schema.attr_weightings_for_indexing()

      writer = KXapianWriter.new(
        KObjectStore.get_text_index_path_for_id(@app_id, :full),
        KObjectStore.get_text_index_path_for_id(@app_id, :fields)
      )

      KApp.logger.info "Starting text indexing for application #{@app_id}"

      # Cache of loaded objects -- worth doing as it's likely that the same objects
      # will be repeated when something linked to by a lot of other objects is updated.
      # Cache object knows how to load objects from the store if they're not present.
      obj_cache = Hash.new do |hash, key|
        obj = nil
        result = KApp.with_pg_database do |pg|
          pg.exec("SELECT object,labels FROM a#{@app_id}.os_objects WHERE id=#{key.obj_id.to_i}")
        end
        if result.length > 0
          hash[key] = obj = KObjectStore._deserialize_object(*result.first)
        end
        obj
      end

      # Start an exception handler block to make sure the database is closed on errors
      begin
        objids_updated = Array.new

        fetched_objs.each do |id_t,type_object_id_t,object_m,labels_m|
          objids_updated << id_t.to_i

          raw_object = KObjectStore._deserialize_object(object_m,labels_m)

          KApp.logger.info "Indexing #{raw_object.objref.to_presentation} for application #{@app_id}"

          begin
            # Delegate may need to alter the indexed object
            object = delegate.indexed_version_of_object(raw_object, store.is_schema_obj?(raw_object))

            # Pass in _unmodified_ object for determining restrictions, as the delegate may have modified it in a way which changes which restrictions match
            objs_to_index = store.__send__(:_ungrouped_object_with_restrictions, object, raw_object)

            # TODO: Should cache be the unaltered object, or the one modified by the plugin? If modified, the obj_cache needs to be updated too
            obj_cache[object.objref] = raw_object

            # If the caller is filtering, check to see if this object should be reindexed
            next if block_given? && !yield(object)

            document = writer.document(id_t.to_i)

            objs_to_index.each do |iobj, restrictions|

              iobj.each do |value,desc,qualifier_v|

                # No qualifier needs to be presented as null
                qualifier = (qualifier_v == nil) ? 0 : qualifier_v

                restriction_labels = restrictions[desc] || []

                if value.kind_of? KObjRef
                  # Add terms from the linked object and parents
                  limit = TEXT_INDEX_MAX_PARENT_COUNT
                  scan = value
                  while limit > 0 && scan && scan.kind_of?(KObjRef)
                    # Don't let bad stores cause infinite loops
                    limit -= 1
                    # Get linked object from store or cache
                    linked_object = obj_cache[scan]
                    if linked_object
                      # Get instructions for which fields to include, and their weights, falling back to a default specification
                      term_inclusion_spec = nil
                      linked_type_desc = schema.type_descriptor(linked_object.first_attr(A_TYPE))
                      if linked_type_desc
                        term_inclusion_spec = linked_type_desc.term_inclusion
                      end
                      term_inclusion_spec ||= KSchema::DEFAULT_TERM_INCLUSION_SPECIFICATION
                      # Include all terms, according to the spec
                      term_inclusion_spec.inclusions.each do |inclusion|
                        linked_object.each(inclusion.desc) do |linked_value,d,q|
                          # Don't index 'slow' text values, eg files
                          if linked_value.k_is_string_type? && !(linked_value.to_terms_is_slow?)
                            # We use the restriction labels of the link
                            # attribute, not those of the attributes on
                            # the linked object. TODO: Look into avoiding
                            # this minor information leak.
                            post_terms(document, attr_weightings, desc, qualifier, restriction_labels, linked_value, inclusion.relevancy_weight)
                          end
                        end
                      end
                      # Parent?
                      scan = linked_object.first_attr(A_PARENT)
                    end
                    # TODO: Optimise indexing of linked values by storing processed terms, rather than repeatedly converting values
                  end

                elsif value.k_is_string_type?
                  post_terms(document, attr_weightings, desc, qualifier, restriction_labels, value)

                end

              end

            end

          rescue => e
            # Exception happened, finish the document (not much else can be done)
            KApp.logger.error "Exception during indexing, object text index will be incomplete for #{raw_object.objref.to_presentation}"
            KApp.logger.log_exception(e)
            # log let the delegate report this.
            delegate.textidx_exception_indexing_object(raw_object, e)
          end

        end

        # Remove the deleted objects
        obj_list.each do |objid|
          unless objids_updated.include?(objid)
            # Object was marked as dirty, but doesn't exist any more. Must have been deleted.
            writer.delete_document(objid)
          end
        end

        writer.write

      ensure
        KApp.logger.info "Finished text indexing for application #{@app_id}"
        KApp.logger.flush_buffered
      end

    end

    # Post terms to database, converting text values to terms
    def post_terms(document, attr_weightings, desc, qualifier, restriction_labels, text_value, relevancy_weight_multipler = nil)
      # Determine weight of this text
      weight = if attr_weightings.has_key?(desc)
        attr_weightings[desc][qualifier] || attr_weightings[desc][0] || TEXTIDX_WEIGHT_MULITPLER
      else
        TEXTIDX_WEIGHT_MULITPLER
      end
      # Only multiply weight if the existing weight is not 0, so disabling works even with the clamp
      if weight > 0 && relevancy_weight_multipler != nil
        weight = ((weight.to_f * relevancy_weight_multipler.to_f) / RELEVANCY_WEIGHT_MULTIPLER.to_f).to_i
        weight = 1 if weight < 1  # clamp it to 1, so it's not irrelevant
      end

      # Get processed and stemmed terms from the text, but only if the weight is greater than zero.
      # Setting relevancy to 0 turns off indexing - value isn't even processed.
      terms = nil
      if weight > 0
        begin
          terms = text_value.to_terms
        rescue => e
          # TODO: Handle exceptions better
          KApp.logger.error("Ignoring exception during text indexing")
          KApp.logger.log_exception(e)
        end
      end

      # Got any terms?
      if terms != nil
        # Prefixes
        p1 = "#{desc.to_s(36)}:"
        p2 = (qualifier == 0) ? nil : "#{desc.to_s(36)}_#{qualifier.to_s(36)}:"

        document.post_terms(terms, restriction_labels, p1, p2, weight)
      end
    end

  end

  # --------------------------------------------------------------------------------------------------------------------

  # Background task
  class IndexingBackgroundTask < KFramework::BackgroundTask
    def start
      KObjectStore.run_text_indexing
    end
    def stop
      KObjectStore.stop_text_indexing
    end
  end

  KFramework.register_background_task(IndexingBackgroundTask.new)

end

