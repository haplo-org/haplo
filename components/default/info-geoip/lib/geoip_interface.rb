# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2018   https://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module GeoIPInterface

  raise 'KINFORMATION_HOME is not set' unless ENV['KINFORMATION_HOME']
  GEOIP_COUNTRY_DB_FILE = "#{ENV['KINFORMATION_HOME']}/maxmind-geolite2/GeoLite2-Country.mmdb"

  @@geoip_country_db = nil

  Java::OrgHaploJsinterface::KPlatformGenericInterface.registerFunction(
    "haplo:info:geoip:lookup",
    "pHaploInfoGeoIpLookup",
    Proc.new do |json|
      response = nil
      begin
        @@geoip_country_db ||= Java::ComMaxmindGeoip2::DatabaseReader::Builder.new(java.io.File.new(GeoIPInterface::GEOIP_COUNTRY_DB_FILE)).build()

        address = JSON.parse(json)['address']
        ip = java.net.InetAddress.getByName(address)
        r = @@geoip_country_db.country(ip)
        if r
          response = {
            'continent' => r.getContinent().getCode(),
            'country' => r.getCountry().getIsoCode()
          }
        else
          response = {'error'=>'unknown'}
        end
      rescue => e
        KApp.logger.error("Error looking up geoip: #{json}")
        KApp.logger.log_exception(e)
        response = {'error'=>'failed'}
      end
      JSON.generate(response)
    end
  )

end
