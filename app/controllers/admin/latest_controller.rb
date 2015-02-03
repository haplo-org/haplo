# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class Admin_LatestController < ApplicationController
  include KConstants
  include LatestUtils    # for settings form code
  include SystemManagementHelper
  include LatestHelper
  policies_required :not_anonymous, :manage_users
  # TODO: Security -- assist_others required, but manage_users necessary for navigating to the page! Probably needs some design work on UI for users etc, or a generic user browser?

  def render_layout
    'management'
  end

  _GetAndPost
  def handle_edit
    @user = User.find(params[:id])
    reqs = LatestRequest.find_all_by_user_id(@user.id)

    if request.post?
      # Build a lookup of objref -> request
      lookup = Hash.new
      reqs.each { |r| lookup[r.objref.to_presentation] = r }

      # Wipe reqs as it'll be rebuilt
      reqs = Array.new

      # Go through values in response
      if params[:r] != nil
        params[:r].each do |k,v|
          inc = v.to_i
          ref = KObjRef.from_presentation(k)
          if ref != nil && inc >= LatestRequest::REQ__MIN && inc <= LatestRequest::REQ__MAX
            # Valid inclusion -- change existing entry or create new?
            existing = lookup[k]
            if existing != nil
              # Needs update?
              if existing.inclusion != inc
                existing.inclusion = inc
                existing.save!
              end
              # Remove from lookup so it doesn't get deleted
              lookup.delete(k)
              # Save in new reqs
              reqs << existing
            else
              # Create new
              n = LatestRequest.new
              n.user_id = @user.id
              n.inclusion = inc
              n.objref = ref
              n.save!
              # Add to array so it's displayed
              reqs << n
            end
          end
        end
        # Now delete anything which wasn't mentioned in the form
        lookup.each_value do |r|
          r.destroy
        end
      end
      redirect_to "/do/admin/user/show/#{@user.id}"
    end

    # Sorted requests
    @requests = reqs.sort { |a,b| a.title <=> b.title }

    # Subject tree source
    @treesource = ktreesource_generate_taxonomy()
  end

  _GetAndPost
  def handle_settings
    @user = User.find(params[:id])
    @template_id = UserData.get(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE)
    # Reset to defaults?
    dont_save = false
    if request.post? && params.has_key?(:todefaults)
      UserData.delete(@user, UserData::NAME_LATEST_EMAIL_FORMAT)
      UserData.delete(@user, UserData::NAME_LATEST_EMAIL_SCHEDULE)
      UserData.delete(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE)
      @template_id = nil
      dont_save = true  # don't allow the helper function to save the form data (which isn't there anyway) or redirect
      redirect_to "/do/admin/user/show/#{@user.id}"
    end
    if request.post? && params.has_key?(:template)
      template = params[:template]
      if template == ''
        @template_id = nil
        UserData.delete(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE)
      else
        @template_id = template.to_i
        UserData.set(@user, UserData::NAME_LATEST_EMAIL_TEMPLATE, @template_id)
      end
      dont_save = true  # not for the settings
      redirect_to "/do/admin/user/show/#{@user.id}"
    end
    # Code for handling the settings is in LatestUtils (defined with the root LatestController)
    latest_settings_form_for_user(@user, "/do/admin/user/show/#{@user.id}", dont_save)
  end

end

