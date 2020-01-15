# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# run as
#    script/runner lib/tasks/update_js_runtime_constants.rb

File.open('lib/javascript/lib/constants.js', 'w') do |file|
  file.write <<__E
/*
 * AUTOMATICALLY GENERATED FILE - DO NOT EDIT
 *
 * Run
 *   script/runner lib/tasks/update_js_runtime_constants.rb
 * to rebuild.
 */
__E
  file.write KSchemaToJavaScript.basic_constants_to_js()
  # Add permission constants
  file.write "_.extend(O,{\n"
  all_perms = 0
  KPermissionRegistry.entries.each do |entry|
    num = 1 << entry.bitfield_index
    all_perms |= num
    file.write "  PERM_#{entry.symbol.to_s.upcase}:#{num},\n"
  end
  file.write <<__E
  PERM_ALL:#{all_perms},
  STATEMENT_ALLOW:#{PermissionRule::ALLOW},
  STATEMENT_DENY:#{PermissionRule::DENY},
  STATEMENT_RESET:#{PermissionRule::RESET},
});
__E
  # Add KDateTime precision constants
  all_precisions = {};
  precisions = KDateTime::PRECISION_OPTIONS.map { |name, value| all_precisions[value] = true; "\n  PRECISION_#{name.upcase}: '#{value}'," } .join
  file.write "_.extend(O,{#{precisions}\n  '$ALL_PRECISIONS':#{all_precisions.to_json}\n});\n"
  # Add HTTP constants
  file.write <<__E
var HTTP = {
  CONTINUE: 100,
  SWITCHING_PROTOCOLS: 101,
  OK: 200,
  CREATED: 201,
  ACCEPTED: 202,
  NON_AUTHORITATIVE_INFORMATION: 203,
  NO_CONTENT: 204,
  RESET_CONTENT: 205,
  PARTIAL_CONTENT: 206,
  MULTIPLE_CHOICES: 300,
  MOVED_PERMANENTLY: 301,
  FOUND: 302,
  SEE_OTHER: 303,
  NOT_MODIFIED: 304,
  USE_PROXY: 305,
  // 306 is unused
  TEMPORARY_REDIRECT: 307,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  PAYMENT_REQUIRED: 402,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  NOT_ACCEPTABLE: 406,
  PROXY_AUTHENTICATION_REQUIRED: 407,
  REQUEST_TIMEOUT: 408,
  CONFLICT: 409,
  GONE: 410,
  LENGTH_REQUIRED: 411,
  PRECONDITION_FAILED: 412,
  REQUEST_ENTITY_TOO_LARGE: 413,
  REQUEST_URI_TOO_LONG: 414,
  UNSUPPORTED_MEDIA_TYPE: 415,
  REQUESTED_RANGE_NOT_SATISFIABLE: 416,
  EXPECTATION_FAILED: 417,
  INTERNAL_SERVER_ERROR: 500,
  NOT_IMPLEMENTED: 501,
  BAD_GATEWAY: 502,
  SERVICE_UNAVAILABLE: 503,
  GATEWAY_TIMEOUT: 504,
  HTTP_VERSION_NOT_SUPPORTED: 505
};
O.NAME_TO_TYPECODE = {
__E
  # Typecode names matching schema requirements
  data_types_without_typo = SchemaRequirements::ATTR_DATA_TYPE.dup
  data_types_without_typo.delete("idsn")
  data_types_without_typo.each do |name,typecode|
    file.write %Q!  "#{name}": #{typecode},\n!
  end
file.write <<__E
};
O.TYPECODE_TO_NAME = {
__E
  data_types_without_typo.each do |name,typecode|
    file.write %Q!  #{typecode}: "#{name}",\n!
  end
file.write <<__E
};
__E
end
