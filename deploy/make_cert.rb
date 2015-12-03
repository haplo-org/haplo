
require 'fileutils'

def fail(string)
  puts string
  exit 1
end

# Hostname (in the mDNS .local domain)
HOSTNAME = ARGV[0]

# Root of certs directorys
CERTS_DIR = "/tmp/haplo-sslcerts"
fail "#{CERTS_DIR} already exists" if File.directory?(CERTS_DIR)
FileUtils.mkdir(CERTS_DIR)

# Keys and certs
def make_key(filename)
  fail "Make key #{filename} failed" unless system "openssl genrsa -out #{CERTS_DIR}/#{filename} 1024"
end
def make_cert(filename, key, common_name, signextra = '')
  crt = IO.popen("openssl req -new -key #{CERTS_DIR}/#{key} -out #{CERTS_DIR}/#{filename}.csr", "w")
  # Must all be '.' except for the common name, to be compatible with the messaging code
  crt.write <<__E
.
.
.
.
.
#{common_name}
.


__E
  sign_cmd = "openssl x509 -req -sha1 #{signextra} -days 3650 -in #{CERTS_DIR}/#{filename}.csr -out #{CERTS_DIR}/#{filename}"
  # Self-sign unless a CA is signing this cert
  sign_cmd << " -signkey #{CERTS_DIR}/#{key}" unless sign_cmd =~ /CAkey/
  fail "Sign cert #{filename} failed" unless system sign_cmd
end

# Self-signed key & cert for main application
make_key("server.key")
make_cert("server.crt", "server.key", "*.#{HOSTNAME}")

# output final instructions
puts <<__E

Now copy the files in /tmp/haplo-sslcerts to /haplo/sslcerts 

__E
