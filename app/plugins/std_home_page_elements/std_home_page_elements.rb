# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class StdHomePageElementsPlugin < KPlugin
  include KConstants
  include ERB::Util
  include DisplayHelper # for user names in noticeboard entries

  _PluginName "Home Page Elements"
  _PluginDescription "Standard elements for the home page."

  FIRST_VAGUELY_ACCEPTABLE_INTERNET_EXPLORER_VERSION = 9
  FIRST_FULLY_FEATURED_INTERNET_EXPLORER_VERSION = 10
  CURRENT_INTERNET_EXPLORER_VERSION = 11
  # NOTE: Internet Explorer doesn't include the 'MSIE' in the UA string in 11 and upwards.
  # http://blogs.msdn.com/b/ieinternals/archive/2013/09/21/internet-explorer-11-user-agent-string-ua-string-sniffing-compatibility-with-gecko-webkit.aspx

  DISCOVERY_LIST = [
    ['std:banners',     'Rotating banners'],
    ['std:browser_check','Check the web browser and display warnings'],
    ['std:noticeboard', 'Noticeboard for news'],
    ['std:object',      'An object displayed in an Element'],
    ['std:recent',      'List of recent changed items'],
    ['std:quick_links', 'Quick links to external web sites']
  ]

  METHODS = {
    'std:banners' => :render_banners,
    'std:browser_check' => :render_browser_check,
    'std:object' => :render_object,
    'std:recent' => :render_recent,
    'std:quick_links' => :render_quick_links,
    'std:noticeboard' => :render_noticeboard
  }

  def hElementDiscover(result)
    result.elements.concat DISCOVERY_LIST
  end

  def hElementRender(result, name, path, object, style, options)
    # Dispatch render request if it's known
    m = METHODS[name]
    return nil if m == nil
    rc = KFramework.request_context
    return nil if rc == nil
    self.send(m, controller, result, path, object, style, options)
    result.stopChain if result.title != nil
  end

  # -----------------------------------------------------------------------------------------------------------------

  def on_install
    # If none of the standard elements are included on the home page, include them now!
    elements = KApp.global(:home_page_elements) || ''
    got_one = false
    METHODS.each do |name,v|
      got_one = true if elements.include?(name)
    end
    return if got_one
    KApp.set_global(:home_page_elements,
      "4 left std:browser_check\n4 left std:noticeboard\n4 right std:recent\n4 right std:quick_links\n#{elements}")
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_browser_check(controller, result, path, object, style, options)
    if controller.request.user_agent =~ /MSIE\s+(\d+)/
      ie_version = $1.to_i
      if ie_version < CURRENT_INTERNET_EXPLORER_VERSION
        result.title = ''
        result.html = '<div class="z__acknowledgment_notice"><div class="z__acknotice_message">'
        if ie_version < FIRST_VAGUELY_ACCEPTABLE_INTERNET_EXPLORER_VERSION
          result.html << <<__E
            <p>You're running a very old version of Internet Explorer. Some things won't look quite right.</p>
            <p>Please upgrade to a modern web browser. For optimal performance, security and visual appearance, we recommend <a href="https://www.google.com/chrome/browser/">Chrome</a>.</p>
__E
        elsif ie_version < FIRST_FULLY_FEATURED_INTERNET_EXPLORER_VERSION
          result.html << "<p>You're running an old version of Internet Explorer. Some features won't be available. Please upgrade to the latest version.</p>"
        else
          result.html << "<p>You're running an old version of Internet Explorer. Please upgrade to the latest version.</p>"
        end
        result.html << '</div></div>'
      end
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_recent(controller, result, path, object, style, options)
    opts = decode_options(options)
    number_items = (opts['items'] || 5)
    recent = AuditEntry.where_labels_permit(:read, AuthContext.user.permissions).where({:displayable => true, :kind => 'CREATE'}).
      limit(number_items + 20). # +20 to allow for a few deletions
      order('id DESC');
    # TODO: It'd be lovely to load objects in bulk to avoid having to inefficiently load them one by one
    html = []
    recent.each do |entry|
      obj = begin
        KObjectStore.read(entry.objref)
      rescue KObjectStore::PermissionDenied
        next # Current labels of object deny access, even though past labels (copied to the AuditEntry) do allow.
      end
      html << controller.render_obj(obj, :searchresultmini) unless !obj || obj.deleted?
      break if html.length >= number_items
    end
    html << '<div class="z__home_page_panel_actions"><a href="/do/recent">More</a></div>'
    result.title = 'Recent additions'
    result.html = html.join('')
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_quick_links(controller, result, path, object, style, options)
    # Get all the quick links
    quick_link_search = KObjectStore.query_and.link(O_TYPE_QUICK_LINK, A_TYPE)
    quick_link_search.add_exclude_labels([O_LABEL_STRUCTURE])
    quick_link_search.maximum_results(32)
    html = '<div class="z__home_page_main_action_link">'
    quick_link_search.execute(:all, :title).each do |obj|
      title = obj.first_attr(KConstants::A_TITLE)
      url = obj.first_attr(KConstants::A_URL)
      if title != nil && url != nil
        html << %Q!<a href="#{h(url)}" target="_blank">#{h(title)}</a>!
      end
    end
    html << '</div>'
    if AuthContext.user.policy.can_create_object_of_type?(KConstants::O_TYPE_QUICK_LINK)
      html << %Q!<div class="z__home_page_panel_actions"><a href="/search?w=%23L#{KConstants::O_TYPE_QUICK_LINK.to_presentation}%23" class="z__home_page_panel_actions_right">Edit links</a><a href="/do/edit?new=#{KConstants::O_TYPE_QUICK_LINK.to_presentation}">Add link</a></div>!
    end
    result.title = 'Quick links'
    result.html = html
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_noticeboard(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Get all the news items
    news_search = KObjectStore.query_and.link(O_TYPE_NEWS, A_TYPE)
    news_search.add_exclude_labels([O_LABEL_STRUCTURE])
    news_search.maximum_results(opts['items'] || 10)
    people_links = Hash.new
    html = ''
    news_search.execute(:all, :date).each do |obj|
      render_options = {}
      # Generate posting link
      posting_user = obj.creation_user_id
      plink = people_links[posting_user] ||= begin
        user_objref = if posting_user == nil || posting_user == KObjectStore::SYSTEM_USER_ID
          nil
        else
          User.cache[obj.creation_user_id].objref
        end
        user_obj = user_objref ? KObjectStore.read_if_permitted(user_objref) : nil
        unless user_obj
          h(User.cache[obj.creation_user_id].name)
        else
          %Q!<a href="#{controller.object_urlpath(user_obj)}">#{h(User.cache[obj.creation_user_id].name)}</a>!
        end
      end
      # Render object, passing in the discovered info
      html << controller.render_obj(obj, :noticeboard, {:noticeboard_plink => plink})
    end
    if AuthContext.user.policy.can_create_object_of_type?(KConstants::O_TYPE_NEWS)
      html << %Q!<div class="z__home_page_panel_actions"><a href="/do/edit?new=#{KConstants::O_TYPE_NEWS.to_presentation}">Add notice</a></div>!
    end
    result.title = 'Noticeboard'
    result.html = html
  end

  # -----------------------------------------------------------------------------------------------------------------

  def render_object(controller, result, path, object, style, options)
    opts = decode_options(options)
    # Decode the object reference
    ref = nil
    ref = KObjRef.from_presentation(opts['ref']) if opts['ref'] != nil
    return unless ref != nil
    obj = KObjectStore.read(ref)
    if obj == nil
      result.title = 'std:object'
      result.html = %Q!<div>#{ref.to_presentation} does not exist</div>!
    else
      result.title = opts['title'] || obj.first_attr(A_TITLE).to_s
      result.html = controller.render_obj(obj, :generalview)
    end
  end

  # -----------------------------------------------------------------------------------------------------------------

  NUM_BANNER_BACKGROUNDS = 3  # how many images there are, matched with CSS

  def render_banners(controller, result, path, object, style, options)
    opts = decode_options(options)
    return unless opts["captions"].kind_of?(Array)
    html = '<div id="z__home_page_banners">'
    choosers = ''
    opts["captions"].each_with_index do |caption, index|
      html << %Q!<div class="z__home_page_banner_container bbg#{index % NUM_BANNER_BACKGROUNDS}"!
      choosers << %Q!<a href="#banner#{index}" id="z__banner_chooser#{index}"!
      if index == 0
        choosers << ' class="z__selected"'
      else
        html << ' style="display:none"'
      end
      choosers << '></a>'
      html << '><div>'
      html << h(caption)
      html << '</div></div>'
    end
    html << '<div class="z__home_page_banner_chooser">'
    html << choosers
    html << '</div></div>'
    controller.client_side_plugin_resource(self, :javascript, 'banner.js')
    controller.client_side_plugin_resource(self, :css, 'banner.css')
    result.title = ''
    result.html = html
  end

  # -----------------------------------------------------------------------------------------------------------------

  def get_plugin_file(filename)
    unless filename == 'banner.css'
      return super
    end
    css = File.open("#{plugin_path}/static/banner.css") { |f| f.read }
    [:data, plugin_rewrite_css(css)]
  end

  # -----------------------------------------------------------------------------------------------------------------

  def decode_options(options)
    return {} if options.empty?
    o = nil
    begin
      o = JSON.parse(options)
    rescue
      # Do nothing
    end
    o || {}
  end

end

