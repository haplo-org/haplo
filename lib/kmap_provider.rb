# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KMapProvider

  Provider = Struct.new(:key, :name, :url_base)

  PROVIDERS = {
    'maps.google.co.uk' => Provider.new('maps.google.co.uk', 'Google Maps (UK)', 'http://maps.google.co.uk/maps?q='),
    'maps.google.com' => Provider.new('maps.google.com', 'Google Maps (Global)', 'http://maps.google.com/maps?q='),
    'multimap.com' => Provider.new('multimap.com', 'Multimap', 'http://www.multimap.com/maps/?qs='),
  }
  PROVIDERS_BY_NAME = PROVIDERS.values.sort { |a,b| a.name <=> b.name }

  # Gets a URL for a postcode, using the provider set for this application
  def self.url_for_postcode(postcode)
    return nil if postcode == nil || postcode !~ /\S/
    provider = PROVIDERS[KApp.global(:map_provider)]
    return nil if provider == nil
    %Q!#{provider.url_base}#{ERB::Util.url_encode(postcode)}!
  end

end
