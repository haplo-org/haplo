# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module LatestUtils; end

class LatestController < ApplicationController
  include KConstants
  include LatestUtils
  policies_required :not_anonymous, :use_latest
  include LatestHelper

  # Add stylesheets for every method
  def post_handle
    client_side_resources :latest_styles
    super
  end

  # TODO: Use paged display for latest results if there are too many? (or at least, sort out the display of the too many message, which will be displayed if there are exactly this number of results.)
  MAX_LATEST_RESULTS = 100

  # --------------------------------------------------------
  # Main display of latest info
  def handle_index
    # TODO: Latest updates selects objects based on creation_time, not updated_at -- should use update time?

    # Date range ... generate a range based on the last week (to midnight tonight) and then work backwards
    @weeks_ago = params[:ago].to_i  # 0 if not specified
    et = Time.now.advance(:days => (7 * (0 - @weeks_ago)) + 1)
    st = et.advance(:days => -7)
    # ... clamping to start and end of days
    @start_time = Time.local(st.year, st.month, st.day, 0, 0)
    @end_time =   Time.local(et.year, et.month, et.day, 0, 0)
    @end_date_display = @end_time.ago(4) # move over midnight boundary

    requests = requests_by(@request_user)

    @requests_lookup = Hash.new
    requests.each { |req| @requests_lookup[req.objref] = req }
    query = query_from_requests requests
    query.constrain_to_time_interval(@start_time, @end_time)
    query.maximum_results MAX_LATEST_RESULTS

    @results = query.execute(:all, :date)
  end

  # --------------------------------------------------------
  # Display choices to make
  def handle_choose
    # Get all the requests for this user and all the groups
    requests = LatestRequest.find_all_relevant_to_user(@request_user)

    # Now work out how to present it all to the user
    @request_selected = Hash.new
    @request_from_groups = Hash.new
    uid = @request_user.id
    requests.each do |r|
      objref = r.objref
      # Did the request come from a group, and therefore should be advertised in the main display?
      @request_from_groups[objref] = true if r.user_id != uid
      # Work out inclusion
      cursel = @request_selected[objref]
      if cursel == nil
        @request_selected[objref] = r
      else
        # Merge
        if r.user_id == uid
          # Current user; change if request is not forced on
          @request_selected[objref] = r unless cursel.inclusion == LatestRequest::REQ_FORCE_INCLUDE
        else
          # One of the groups about the user
          @request_selected[objref] = r if r.inclusion > cursel.inclusion
        end
      end
    end
    @advertised_requests = Hash.new
    user_requests = Array.new
    @request_selected.each_value do |r|
      if @request_from_groups[r.objref]
        # Put into advertised by type
        t = r.type
        @advertised_requests[t] ||= Array.new
        @advertised_requests[t] << r
      else
        # User request
        user_requests << r
      end
    end
    # Sort requests within type groups by name
    @advertised_requests.each_value { |g| g.sort! { |a,b| a.title <=> b.title } }
    user_requests.sort! { |a,b| a.title <=> b.title }
    # Get names of types
    @type_names = Hash.new
    type_refs = @advertised_requests.keys
    type_refs.each do |t|
      @type_names[t] = KObjectStore.read(t).first_attr(A_TITLE).to_s
    end
    # Sort the type refs by name
    @types_sorted_by_name = type_refs.sort do |a,b|
      @type_names[a] <=> @type_names[b]
    end
    # Add in the user requests
    @advertised_requests[:user_requests] = user_requests
    @types_sorted_by_name << :user_requests
  end

  # --------------------------------------------------------
  # Update choices
  _PostOnly
  def handle_update
    if request.post?
      choices = Hash.new
      if params.has_key?(:r)
        params[:r].each_key { |k| choices[KObjRef.from_presentation(k)] = true }
      end

      requests = LatestRequest.find_all_relevant_to_user(@request_user)

      uid = @request_user.id

      # Find requests inherited from groups, those forced on, and the current requests made by the user
      group_selection = Hash.new
      forced = Hash.new
      user_requests = Hash.new
      requests.each do |req|
        if req.user_id == uid
          user_requests[req.objref] = req
        else
          case req.inclusion
          when LatestRequest::REQ_INCLUDE;        group_selection[req.objref] = true
          when LatestRequest::REQ_FORCE_INCLUDE;  forced[req.objref] = true
          end
        end
      end

      # Remove all forced choices
      forced.each_key do |objref|
        if user_requests[objref] != nil
          user_requests[objref].destroy
          user_requests.delete objref
        end
        # And remove from the group selection too, so they don't get added in the next phase
        group_selection.delete objref
      end

      # Switch off items requested by groups, if there's the option
      group_selection.each_key do |objref|
        unless choices[objref]
          # Not selected, make sure there's something removing it
          r = user_requests[objref]
          if r != nil
            # Make sure this is switched off
            if r.inclusion != LatestRequest::REQ_EXCLUDE
              r.inclusion = LatestRequest::REQ_EXCLUDE
              r.save!
            end
            # Delete from user_requests so it doesn't get deleted later
            user_requests.delete objref
          else
            # Make a new request to switch it off
            r = LatestRequest.new
            r.user_id = uid
            r.objref = objref
            r.inclusion = LatestRequest::REQ_EXCLUDE
            r.save!
          end
        end
      end

      # Go through postitive requests, and make sure that everything is selected
      choicesk = choices.keys.dup
      choicesk.each do |objref|
        # Make sure it's necessary
        unless group_selection[objref] || forced[objref]
          # Is there a request?
          r = user_requests[objref]
          if r != nil
            # Switched on?
            if r.inclusion != LatestRequest::REQ_INCLUDE
              r.inclusion = LatestRequest::REQ_INCLUDE
              r.save!
            end
            # Delete from user_requests so it doesn't get deleted later
            user_requests.delete objref
          else
            # New request to switch on
            r = LatestRequest.new
            r.user_id = uid
            r.objref = objref
            r.inclusion = LatestRequest::REQ_INCLUDE
            r.save!
          end
        end
      end

      # Remove any user_requests which are left over
      user_requests.each_value do |req|
        req.destroy
      end
    end

    redirect_to '/do/latest'
  end

  # --------------------------------------------------------
  # Lookup objects for adding to selected subjects
  # NOTE: Also used by the admin latest controller, UI included via the partial.
  def handle_object_lookup_api
    obj_type = KObjRef.from_presentation(params[:t])
    query = params[:q]
    if query != nil && query =~ /\w/
      q = KObjectStore.query_and.link(obj_type, A_TYPE)
      q.free_text(query)
      q.add_exclude_labels([O_LABEL_STRUCTURE])
      q.maximum_results(20)
      @results = q.execute(:all, :title)
    end
    render :layout => false
  end

  # --------------------------------------------------------
  # Change settings
  _GetAndPost
  def handle_settings
    # Code for handling the settings is in LatestUtils
    latest_settings_form_for_user(@request_user, '/do/latest')
  end

end

