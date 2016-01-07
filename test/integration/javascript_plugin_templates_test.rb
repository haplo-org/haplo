# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class JavaScriptPluginTemplatesTest < IntegrationTest

  KJavaScriptPlugin.register_javascript_plugin("#{File.dirname(__FILE__)}/javascript/javascript_plugin_templates/test_plugin_templates")

  def test_plugin_templates
    KPlugin.install_plugin("test_plugin_templates")

    get '/do/plugin-templates/new'
    assert_select '#z__page_name h1', 'New templates'
    assert_select("#z__heading_back_nav a", {:text => "&amp;back", :attributes => {'href'=>'/abc/d?what=New#hello&'}})
    check_response('New template')
    # Check deferredRender() for legacy Handlebars templates
    assert_select '.deferred-bars', "Deferred Handlebars: DEFVAL"

    get '/do/plugin-templates/legacy'
    assert_select '#z__page_name h1', 'Legacy templates'
    check_response('Legacy handlebars template')

    get '/do/plugin-templates/page-title-and-back-link'
    assert_select '#z__page_name h1', 'A abc &amp;&gt;&lt; Z'
    assert_select("#z__heading_back_nav a", {:text => "&lt;&gt;&amp;back", :attributes => {'href'=>'/page/one/two?x=YYY%20%3C%26%3E'}})

    get '/do/plugin-templates/layout/s'
    assert_select '#z__action_entry_points', :count => 1
    assert_select '.z__page_wide_layout', :count => 0
    get '/do/plugin-templates/layout/w'
    assert_select '#z__action_entry_points', :count => 1
    assert_select '.z__page_wide_layout', :count => 1
    get '/do/plugin-templates/layout/m'
    assert_select 'body.z__minimal_layout', :count => 1
    get '/do/plugin-templates/layout/n'
    assert_equal '<p>Text</p>', response.body

    get '/do/plugin-templates/resources'
    assert_select '#resources-template', "Resources Template"
    ["/a.js", "/b.js", "/c.css", "/d.css"].each do |s|
      assert response.body.include?(s)
    end
  ensure
    KPlugin.uninstall_plugin("test_plugin_templates")
  end

  def check_response(kind_name)
    assert_select '#template-kind', kind_name
    # Check each type can include the other
    assert_select '#nested1', 'Nested new'
    assert_select '#nested2', 'Nested Handlebars'
    # Check the standard template was rendered
    assert_select '#test-choose .z__ui_choose_container .z__ui_choose_option_entry[href=/url/one]', 'Label One'
  end

end
