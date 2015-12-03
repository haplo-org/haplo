# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KJSFileTransformPipeline < KJob

  TRANSFORMS = {}

  # -------------------------------------------------------------------------

  def self.verify_transform(transform_name, specification_json)
    transform_implementation = TRANSFORMS[transform_name]
    raise JavaScriptAPIError, "No transform implemented for name #{transform_name}" unless transform_implementation
    transform = transform_implementation.new(JSON.parse(specification_json))
    transform.verify()
  end

  # -------------------------------------------------------------------------

  def initialize(json)
    @json = json
    @files = {}
    @temp_pathname_prefix = "#{FILE_UPLOADS_TEMPORARY_DIR}/tmp.pipeline.#{Thread.current.object_id}.#{self.object_id}"
    @temp_files = []  # pathnames
  end

  PrepareData = Struct.new(:name, :filename, :redirect_to, :plugin_view)

  def prepare
    pipeline = JSON.parse(@json)
    # Tell the generated file controller that these identifiers are valid
    pipeline['waitUI'].each do |name, filename, redirect_to, identifier, plugin_view|
      begin
        plugin_view = {} unless plugin_view.kind_of?(Hash)
        data = PrepareData.new(name, filename, redirect_to, plugin_view)
        KNotificationCentre.notify(:jsfiletransformpipeline, :prepare, identifier, data)
      rescue => e
        KApp.logger.error("Exception sending notification of generated output: #{@json}")
        KApp.logger.log_exception(e)
      end
    end
  end

  def run(context)
    begin
      result = Result.new(self)
      pipeline = nil
      begin
        pipeline = JSON.parse(@json)
        result.name = pipeline['name']
        result.data = pipeline['data']
        # Load StoredFiles for the initial input files
        pipeline['files'].each do |name, digest, file_size|
          stored_file = StoredFile.from_digest_and_size(digest, file_size)
          raise JavaScriptAPIError, "Stored file not available in store: #{digest}, #{file_size}" unless stored_file
          @files[name] = StoredFileListEntry.new(stored_file)
        end
        # Run the pipelined transforms
        pipeline['transforms'].each do |transform_name, transform_specification|
          transform_implementation = TRANSFORMS[transform_name]
          raise JavaScriptAPIError, "No transform implemented for name #{transform_name}" unless transform_implementation
          transform = transform_implementation.new(transform_specification)
          transform.execute(self)
        end
      rescue => e
        # report exception to JS
        result.error_message = e.to_s
        # and log...
        KApp.logger.error("Exception running JS pipeline: #{@json}")
        KApp.logger.log_exception(e)
      end
      # Notify generated file downloads
      pipeline['waitUI'].each do |name, filename, redirect_to, identifier|
        begin
          success = result.success; disk_pathname = nil; mime_type = nil
          if success && name
            # Waiting for a particular file
            file_list_entry = @files[name]
            if file_list_entry
              disk_pathname = file_list_entry.disk_pathname
              mime_type = file_list_entry.mime_type
            else
              success = false
            end
          end
          if success
            KNotificationCentre.notify(:jsfiletransformpipeline, :ready, identifier, disk_pathname, mime_type)
          else
            KNotificationCentre.notify(:jsfiletransformpipeline, :failure, identifier)
          end
        rescue => e
          KApp.logger.error("Exception sending notification of generated output: #{@json}")
          KApp.logger.log_exception(e)
        end
      end
      # Call back into JavaScript to use the result
      KNotificationCentre.notify(:jsfiletransformpipeline, :pipeline_result, result)
      KJSPluginRuntime.current.call_file_transform_pipeline_callback(result)
    ensure
      # Clean up any temporary files which weren't consumed by the callback
      @temp_files.each do |temp_pathname|
        File.unlink(temp_pathname) if File.exist?(temp_pathname)
      end
    end
  end

  def default_queue
    KJob::QUEUE_FILE_TRANSFORM_PIPELINE
  end

  # -------------------------------------------------------------------------

  def get_file(name)
    file_list_entry = @files[name]
    raise JavaScriptAPIError, "Unknown file: #{name}" unless file_list_entry
    file_list_entry
  end

  def set_file(name, file_list_entry)
    raise JavaScriptAPIError, "Bad file" unless file_list_entry.kind_of?(FileListEntry)
    @files[name] = file_list_entry
  end

  # Temporary pathnames will be automatically deleted when application is exited
  def make_managed_temporary_file_pathname
    pathname = "#{@temp_pathname_prefix}.#{@temp_files.length}"
    @temp_files << pathname
    pathname
  end

  # -------------------------------------------------------------------------

  class Result
    def initialize(pipeline)
      @pipeline = pipeline
    end
    attr_accessor :name, :error_message
    attr_writer :data
    def success
      @error_message == nil
    end
    def dataJSON
      JSON.generate(@data || {});
    end
    def get_stored_file(name, filename)
      file = @pipeline.get_file(name)
      file.to_stored_file(KMIMETypes.correct_filename_extension(file.mime_type, filename))
    end
  end

  # -------------------------------------------------------------------------

  # Common specification keys:
  #   "input" - name of input file (defaults to "input")
  #   "output" - name of output file (defaults to "output")
  class TransformImplementation
    def initialize(specification)
      @specification = specification
    end
    def verify
      # Nothing by default
      # Subclass should throw a JavaScriptAPIError if @specification isn't valid
    end
    def execute(pipeline)
      raise "No implementation"
    end
    # Default input/output names
    def input_name
      @specification['input'] || 'input'
    end
    def output_name
      @specification['output'] || 'output'
    end
  end

  # -------------------------------------------------------------------------

  # Specification has one key, "rename", which is an array of ["from", "to"] renames.
  class RenameFilesTransform < TransformImplementation
    def verify
      renames = @specification['rename']
      raise JavaScriptAPIError, "Bad std:file:rename transform, must have 'rename' option as arrays of arrays" unless renames && renames.kind_of?(Array)
      renames.each do |from_name, to_name|
        unless from_name.kind_of?(String) && to_name.kind_of?(String)
          raise JavaScriptAPIError, "Bad std:file:rename transform, 'rename' should be array of arrays of string pairs."
        end
      end
    end
    def execute(pipeline)
      # Rename in two steps so files could be swapped
      (@specification['rename'] || []).map do |from_name, to_name|
        [pipeline.get_file(from_name), to_name]
      end .each do |file_list_entry, to_name|
        pipeline.set_file(to_name, file_list_entry)
      end
    end
  end
  TRANSFORMS['std:file:rename'] = RenameFilesTransform

  # -------------------------------------------------------------------------

  # Specification has:
  #   "mimeType" - output MIME type (required)
  #   "options" - various options, see OPTIONS below (optional)
  class ConvertFileTransform < TransformImplementation
    OPTIONS = [
        ["width",   :w,     1,  4096],
        ["height",  :h,     1,  4096],
        ["quality", :q,     1,  100],
        ["page",    :page,  1]
      ]
    def verify
      raise JavaScriptAPIError, "No output MIME type specified" unless @specification.has_key?('mimeType')
      conversion_options() # to check options are valid
    end
    def execute(pipeline)
      input = pipeline.get_file(self.input_name)
      output_mime_type = @specification['mimeType']
      if (input.mime_type == output_mime_type) && !(@specification.has_key?('options'))
        # No transform necessary
        pipeline.set_file(self.output_name, input)
        return
      end
      transformer = KFileTransform.get_transformer(input.mime_type, output_mime_type)
      raise JavaScriptAPIError, "Can't convert from #{input.mime_type} to #{output_mime_type}" unless transformer
      output_pathname = pipeline.make_managed_temporary_file_pathname()
      operation = transformer.make_op(input.disk_pathname, output_pathname, input.mime_type, output_mime_type, conversion_options())
      operation.perform()
      success = transformer.complete_op(operation)
      if success && File.exist?(output_pathname)
        pipeline.set_file(self.output_name, GeneratedFileListEntry.new(output_pathname, output_mime_type))
      else
        raise JavaScriptAPIError, "Failed to convert file from #{input.mime_type} to #{output_mime_type}"
      end
    end
    def conversion_options
      options = {}
      spec_options = @specification['options'] || {}
      raise JavaScriptAPIError, "'options' must be a dictionary object." unless spec_options.kind_of?(Hash)
      OPTIONS.each do |key, symbol, min, max|
        value = spec_options[key]
        if value
          raise JavaScriptAPIError, "Bad value for option #{key}" unless value.kind_of?(Numeric)
          raise JavaScriptAPIError, "Option #{key} should be greater or equal to #{min}" unless value >= min
          raise JavaScriptAPIError, "Option #{key} should be less than or equal to #{max}" unless max.nil? || (value <= max)
          options[symbol] = value
        end
      end
      options.empty? ? nil : options
    end
  end
  TRANSFORMS['std:convert'] = ConvertFileTransform

  # -------------------------------------------------------------------------

  class FileListEntry
    def to_stored_file(filename); raise "Not implemented"; end
    def disk_pathname; raise "Not implemented"; end
    def mime_type; raise "Not implemented"; end
    def display_name; nil; end
    def details; {}; end
  end

  class StoredFileListEntry < FileListEntry
    def initialize(stored_file)
      @stored_file = stored_file
    end
    def to_stored_file(filename)
      @stored_file
    end
    def disk_pathname
      @stored_file.disk_pathname
    end
    def mime_type
      @stored_file.mime_type
    end
    def display_name
      @stored_file.upload_filename
    end
  end

  class GeneratedFileListEntry < FileListEntry
    def initialize(disk_pathname, mime_type, details = nil)
      @disk_pathname = disk_pathname
      @mime_type = mime_type
      @details = details || {}
    end
    def to_stored_file(filename)
      StoredFile.move_file_into_store(@disk_pathname, filename, mime_type)
    end
    def disk_pathname
      @disk_pathname
    end
    def mime_type
      @mime_type
    end
    def details
      @details
    end
  end

end
