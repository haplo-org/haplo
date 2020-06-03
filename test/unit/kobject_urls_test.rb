
# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KObjectURLsTest < Test::Unit::TestCase
  include KConstants
  include KObjectURLs
  include Application_TextHelper
  include Application_RenderHelper

  def test_object_url_generation
    [
      ["a-long-title-with-snowman-charac",  "A long title with ☃ (snowman) characters which will be truncated"],
      ["text-bold2",                        KTextFormattedLine.new('<fl>Text <b>Bold</b><sup>2</sup></fl>')]
    ].each do |expected_slug, title|
      obj = KObject.new
      obj.add_attr(O_TYPE_BOOK, A_TYPE)
      obj.add_attr(title, A_TITLE)
      KObjectStore.create(obj)

      # URL path generation
      assert_equal "/#{obj.objref.to_presentation}/#{expected_slug}", object_urlpath(obj)

      # Test the urls embedded in generated links
      assert_equal "<a href=\"/#{obj.objref.to_presentation}/#{expected_slug}\">TEXT</a>", link_to_object('TEXT', obj)
    end
  end

end

