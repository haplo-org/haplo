# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Helpers for generating HTML

class Documentation

  def self.html_node_navigation(node)
    expand_list = []
    scan = node
    while scan != nil
      expand_list << scan
      scan = scan.parent
    end
    html_node_navigation_children_list(@@root, expand_list, node, 0)
  end

  def self.html_node_navigation_children_list(node, expand_list, displayed_node, depth)
    html = '<ul>'
    node.sorted_children.each do |n|
      if n == displayed_node
        html << %Q!<li><b>#{ERB::Util::h(n.title)}</b>!
      else
        html << %Q!<li><a href="#{n.url_path}"!
        if expand_list.include?(n)
          html << ' class="open"'
        end
        html << %Q!>#{ERB::Util::h(n.title)}</a>!
      end
      if expand_list.include?(n)
        html << html_node_navigation_children_list(n, expand_list, displayed_node, depth+1)
      end
      html << '</li>'
      html << '<hr>' if depth==0
    end
    html << '</ul>'
  end

  def self.html_breadcrumb(node)
    expand_list = []
    scan = node
    while scan != nil
      expand_list << scan
      scan = scan.parent
    end
    html_breadcrumb_children_list(@@root, expand_list, node)
  end

  def self.html_breadcrumb_children_list(node, expand_list, displayed_node)
    html = ''
    node.sorted_children.each do |n|
      if n == displayed_node
        html << %Q!<b>#{ERB::Util::h(n.title)}</b>!
      else
        if expand_list.include?(n)
          html << %Q!<a href="#{n.url_path}">#{ERB::Util::h(n.title)}</a> &raquo !
        end
      end
      if expand_list.include?(n)
        html << html_breadcrumb_children_list(n, expand_list, displayed_node)
      end
    end
    html
  end


  # ------------------------------------------------------------------------------------

  ANCHOR_POINT_KINDS_FOR_CODE = ['function', 'property', 'key']

  # For main generation script
  def self.rewrite_html(html)
    html = html.dup
    # Rewrite node links
    html.gsub!(/\[node\:([a-zA-Z0-9\/-]+(#[a-zA-Z0-9\/_-]*)?)(:([^\]]+?))?\]/) do
      node_path_full = $1
      caption_src = $4
      node_path, node_path_heading = node_path_full.split('#')
      anchor = (node_path_heading == nil) ? '' : "##{node_path_heading}"
      linked_node = get_node(node_path)
      raise "Can't find node for '#{node_path}'" if linked_node == nil
      caption = caption_src || ERB::Util::h(linked_node.title)
      display_as_code = (linked_node.attributes[:link_as] == 'keyword' && caption_src == nil)
      # If there's an heading linked, display the heading instead
      if node_path_heading != nil
        anchor_point_kind, anchor_point_heading = linked_node.anchor_point_info(node_path_heading)
        raise "Couldn't find anchor point #{node_path_full}" if anchor_point_kind == nil
        # Override display and code depending on the kind of heading
        display_as_code = ANCHOR_POINT_KINDS_FOR_CODE.include?(anchor_point_kind)
        caption = anchor_point_heading if caption_src == nil
      end
      lh = %Q!<a class="doclink" href="#{linked_node.url_path}#{anchor}">#{caption}</a>!
      lh = %Q!<code>#{lh}</code>! if display_as_code
      lh
    end
    # Check for bad [node: ...] links
    raise "Bad node link #{$1}" if html =~ /(\[node:.+?\])/
    # External links
    html.gsub!(/(<a href="https?\:[^"]+)">(.+?)<\/a>/) do
      %Q!#{$1}" class="external_link" target="_blank">#{$2}</a>!
    end
    # Where to click in the UI
    html.gsub!(/<p>CLICK_PATH\s*(.+?)<\/p>/) do
      c = $1.
        gsub('&gt;','&raquo;'). # change arrows
        gsub('TOOLS', '<span class="clickpath_tools">Your Name</span>') # change TOOLS for new-look user name, with gear icon
      %Q!<div class="clickpath"><span class="clickpath_inner">#{c}</span></div>!
    end
    # Preliminary documentation
    html.gsub!('<p>BEGIN_PRELIMINARY</p>', '<div class="preliminary_header">PRELIMINARY API &mdash; ALL DETAILS SUBJECT TO CHANGE</div><div class="preliminary">')
    html.gsub!('<p>END_PRELIMINARY</p>', '</div>')
    # Endpoints
    html.gsub!(/<p>API_ENDPOINT\s*(.+?)\s*(\(.+?\))<\/p>/) do
      %Q!<div class="api_endpoint"><span class="api_endpoint_inner"><span class="api_endpoint_label">ENDPOINT</span> <code>#{$1}</code> <span class="api_endpoint_methods">#{$2}</span></span></div>!
    end
    # Is there anything which needs syntax highlighting?
    required_syntax_highlighters = Hash.new
    html.gsub!(/\<pre\>language=(\w+)/) do
      highlighter, language = SYNTAX_HIGHLIGHTER[$1]
      raise "Bad syntax highlighter language $1" unless highlighter != nil
      required_syntax_highlighters[highlighter] = true
      %Q!<pre class="brush: #{language}">!
    end
    unless required_syntax_highlighters.empty?
      loader = %Q!<link href="/presentation/syntaxhighlighter/shCoreDefault.css" rel="stylesheet" type="text/css"><script src="/presentation/syntaxhighlighter/shCore.js"></script>!
      required_syntax_highlighters.each_key do |highlighter|
        loader << %Q!<script src="/presentation/syntaxhighlighter/#{highlighter}.js"></script>!
      end
      loader << %Q!<script>SyntaxHighlighter.all()</script>!
      html.gsub!('</body>',loader+"\n</body>")
    end
    # Rewrite javascript api keys
    html.gsub!(/\<h(\d) class="(key|value|function|property|acts_as)">/) do
      %Q!<h#{$1} class="jsapi #{$2}"><span class="apilabel">#{$2.gsub('_',' ')}</span> !
    end
    html
  end

  SYNTAX_HIGHLIGHTER = {
    'json' => ['shBrushJScript', 'js'],
    'javascript' => ['shBrushJScript', 'js'],
    'xml' => ['shBrushXml', 'xml']
  }

end
