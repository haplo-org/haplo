# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


class KIdentifierFile < KIdentifier
  ktext_typecode KConstants::T_IDENTIFIER_FILE, 'File'

  FIRST_VERSION_STRING = "1".freeze # sync with keditor.js

  # Instance vars are short to save space when serialised
  def _components_for_equality_check
    [@d, @s, @m, @l, @v] # NOTE: Does not include the tracking ID
  end
  def digest; @d; end
  def digest=(d); @d = valid_text_component(d, /\A[a-f0-9]{64,64}\z/, :digest); end
  def size; @s; end
  def size=(s); @s = s.to_i; end
  def presentation_filename; @text; end # uses main KText storage for filename
  def presentation_filename=(f); @text = KText.ensure_utf8(f); end
  def mime_type; @m; end
  def mime_type=(m); @m = KText.ensure_utf8(m); end
  def tracking_id; @i; end
  def tracking_id=(i); @i = valid_text_component(i, /\A[a-zA-Z0-9_-]+\z/, :tracking_id); end
  def log_message; @l; end
  def log_message=(l); @l = KText.ensure_utf8(l); end
  def version_string; @v; end # version 'number' is an arbitary string
  def version_string=(v); @v = KText.ensure_utf8(v); end
  def valid_text_component(t, regexp, name)
    t = KText.ensure_utf8(t)
    raise "Bad #{name}" unless t =~ regexp
    t
  end

  def initialize(stored_file, tracking_id = nil)
    super(stored_file ? stored_file.upload_filename : '')
    if stored_file
      # Use accessors so the values are checked and converted
      self.digest = stored_file.digest
      self.size = stored_file.size
      self.mime_type = stored_file.mime_type
      self.tracking_id = (tracking_id ||= KRandom.random_api_key(KRandom::FILE_IDENTIFIER_TRACKING_ID_LENGTH))
    end
    # FILE TODO: Configurable first version number for stored file identifiers, maybe allow plugins to specify somehow? (note client side code will have to be changed as well)
    self.version_string = FIRST_VERSION_STRING.dup
  end

  # Override superclass equality
  def ==(other)
    super(other) && (_components_for_equality_check() == other._components_for_equality_check())
  end
  def hash
    @d.hash
  end

  def to_html
    ''      # Don't display anything; let other things generate the HTML because it requires a bit of context
  end

  def to_export_cells
    # Use the filename in the export, not all the component fields
    presentation_filename
  end

  def find_stored_file
    StoredFile.from_identifier(self)
  end

  def to_indexable
    raise "KIdentifierFile#to_indexable cannot be used"
  end

  def to_summary
    stored_file = StoredFile.from_identifier(self)
    return nil unless stored_file
    num_chars = stored_file.render_text_chars
    (num_chars && num_chars > 256) ? stored_file.render_text : nil
  end

  def to_terms
    KTextExtract.extract_from(self.find_stored_file)
  end
  def to_terms_is_slow?
    true  # text extraction requires a lot of work in a worker process
  end
  def to_terms_comparison_value
    raise "Logic error -- to_terms_comparison_value called when to_terms_is_slow? on a KIdentifierFile"
  end

  def to_identifier_index_str
    # Use the digest+size as the unique part of the identifier
    "#{self.digest},#{self.size}"
  end

  # Secrets for client side round trips
  def generate_secret
    StoredFile.generate_secret(self.digest, self.size)
  end
  def verify_secret!(given_secret)
    unless StoredFile.compare_secret(given_secret, self.generate_secret)
      raise "Bad file identifier secret"
    end
  end

  # ---------------------------------------------------------------------------------------------------------------

  # JSON support (including secret verification for security)
  def to_json
    fields = {
      :digest => self.digest,
      :fileSize => self.size,
      :secret => self.generate_secret,
      :filename => self.presentation_filename,
      :mimeType => self.mime_type,
      :trackingId => self.tracking_id,
      :version => self.version_string
    }
    fields[:logMessage] = self.log_message if self.log_message
    JSON.generate(fields)
  end

  def self.from_json(json)
    fields = JSON.parse(json)
    identifier = KIdentifierFile.new(nil)
    identifier.digest = fields['digest']
    identifier.size = fields['fileSize']
    identifier.presentation_filename = fields['filename']
    identifier.mime_type = fields['mimeType']
    identifier.tracking_id = fields['trackingId']
    identifier.log_message = fields['logMessage'] if fields.has_key?('logMessage')
    identifier.version_string = fields['version']
    identifier.verify_secret!(fields["secret"]) # security check
    identifier
  end

  # ---------------------------------------------------------------------------------------------------------------

  # XML export
  def build_xml(builder)
    builder.file_reference do |ref|
      ref.digest self.digest
      ref.file_size self.size
      ref.secret self.generate_secret
      ref.filename self.presentation_filename
      ref.mime_type self.mime_type
      ref.tracking_id self.tracking_id
      ref.log_message self.log_message if self.log_message
      ref.version self.version_string
    end
  end
  # XML import (including secret verification for security)
  XML_FIELDS = [
      ['digest', :digest=],
      ['file_size', :size=],
      ['filename', :presentation_filename=],
      ['mime_type', :mime_type=],
      ['tracking_id', :tracking_id=],
      ['version', :version_string=]
    ]
  def self.read_from_xml(xml_container)
    identifier = KIdentifierFile.new(nil)
    e = xml_container.elements["file_reference"]
    XML_FIELDS.each do |name, method|
      x = e.elements[name]
      raise "Bad XML file reference" if x == nil
      identifier.__send__(method, x.text)
    end
    log_element = e.elements['log_message']
    identifier.log_message = log_element.text if log_element
    secret_element = e.elements['secret']
    raise "No secret in XML" unless secret_element
    identifier.verify_secret!(secret_element.text) # security check
    identifier
  end
end
