# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KMIMETypes

  # MS types: http://support.microsoft.com/kb/936496

  TYPE_ICONS = {
    'application/pdf' => 'pdf',
    'application/msword' => 'word',
    'application/vnd.ms-excel' => 'excel',
    'application/vnd.ms-powerpoint' => 'powerpoint',
    'application/vnd.ms-project' => 'project',
    'application/vnd.visio' => 'visio',
    'application/x-msaccess' => 'access',
    'application/vnd.ms-project' => 'project',
    'application/x-mspublisher' => 'publisher',
    'application/msonenote' => 'onenote',
    'application/vnd.oasis.opendocument.text' => 'oodoc',
    'application/vnd.oasis.opendocument.text-template' => 'oodoc',
    'application/vnd.oasis.opendocument.graphics' => 'oodraw',
    'application/vnd.oasis.opendocument.graphics-template' => 'oodraw',
    'application/vnd.oasis.opendocument.presentation' => 'oopres',
    'application/vnd.oasis.opendocument.presentation-template' => 'oopres',
    'application/vnd.oasis.opendocument.spreadsheet' => 'oocalc',
    'application/vnd.oasis.opendocument.spreadsheet-template' => 'oocalc',
    'application/vnd.oasis.opendocument.chart' => 'oo',
    'application/vnd.oasis.opendocument.chart-template' => 'oo',
    'application/vnd.oasis.opendocument.image' => 'oo',
    'application/vnd.oasis.opendocument.image-template' => 'oo',
    'application/vnd.oasis.opendocument.formula' => 'oo',
    'application/vnd.oasis.opendocument.formula-template' => 'oo',
    'application/vnd.oasis.opendocument.text-master' => 'oo',
    'application/vnd.oasis.opendocument.text-web' => 'oo',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.template' => 'excel',
    'application/vnd.openxmlformats-officedocument.presentationml.template' => 'powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.slideshow' => 'powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.slide' => 'powerpoint',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'word',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.template' => 'word',
    'application/x-iwork-pages-sffpages' => 'iwpages',
    'application/x-iwork-pages-sfftemplate' => 'iwpgtmpl',
    'application/x-iwork-keynote-sffkey' => 'iwkey',
    'application/x-iwork-keynote-sffkth' => 'iwkth',
    'application/x-iwork-numbers-sffnumbers' => 'iwnum',
    'application/x-iwork-numbers-sfftemplate' => 'iwnmtmpl'
  }

  # Offical definitions at http://www.iana.org/assignments/media-types/application/
  MIME_TYPE_CORRECTIONS = {
    'image/x-png' => 'image/png',         # an odd one, picked up from an MSIE 7.0 installation
    'image/jpg' => 'image/jpeg',          # just in case
    'image/pjpeg' => 'image/jpeg',        # IEism for progressive JPEGs?
    'text/rtf' => 'application/rtf',      # Both IANA registered, but RTF is not a standard
    'application/doc' => 'application/msword',
    'application/vnd.msword' => 'application/msword',
    'application/vnd.ms-word' => 'application/msword',
    'application/msexcel' => 'application/vnd.ms-excel',
    'application/x-msexcel' => 'application/vnd.ms-excel',
    'application/x-excel' => 'application/vnd.ms-excel',
    'application/xls' => 'application/vnd.ms-excel',
    'application/mspowerpoint' => 'application/vnd.ms-powerpoint',
    'application/ms-powerpoint' => 'application/vnd.ms-powerpoint',
    'application/vnd.mspowerpoint' => 'application/vnd.ms-powerpoint',
    'application/powerpoint' => 'application/vnd.ms-powerpoint'
  }

  # Load mime types from Apache defn
  extns = Hash.new
  File.open(File.dirname(__FILE__) + "/mime.types" ,"r") do |f|
    f.each_line do |line|
      unless line =~ /\s*\#/ || line !~ /\S/
        e = line.chomp.split(/\s+/)
        t = e.shift                   # mime type is first entry
        unless t == 'application/octet-stream'
          e.each { |ex| extns[ex] = t } # extensions, probably none
        end
      end
    end
  end
  # Use the definitions from Apache's list, updated with extensions we definately want to be set to particular values
  # These 'OVERRIDES' values are always used when something of that extension is uploaded
  MIME_TYPE_FROM_EXTENSION_OVERRIDES = {
    'pdf' => 'application/pdf',
    'rtf' => 'application/rtf',     # Windows sometimes uploads it as text/richtext (!)
    'doc' => 'application/msword',
    'dot' => 'application/msword',
    'xls' => 'application/vnd.ms-excel',
    'xlm' => 'application/vnd.ms-excel',
    'xla' => 'application/vnd.ms-excel',
    'xlt' => 'application/vnd.ms-excel',
    'xlc' => 'application/vnd.ms-excel',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pot' => 'application/vnd.ms-powerpoint',
    'vsd' => 'application/vnd.visio',
    'vdx' => 'application/vnd.visio',
    'vtx' => 'application/vnd.visio',
    'vsw' => 'application/vnd.visio',
    'vsx' => 'application/vnd.visio',
    'mdb' => 'application/x-msaccess',
    'mpp' => 'application/vnd.ms-project',
    'pub' => 'application/x-mspublisher',
    'one' => 'application/msonenote',
    'odt' => 'application/vnd.oasis.opendocument.text',
    'ott' => 'application/vnd.oasis.opendocument.text-template',
    'odg' => 'application/vnd.oasis.opendocument.graphics',
    'otg' => 'application/vnd.oasis.opendocument.graphics-template',
    'odp' => 'application/vnd.oasis.opendocument.presentation',
    'otp' => 'application/vnd.oasis.opendocument.presentation-template',
    'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
    'ots' => 'application/vnd.oasis.opendocument.spreadsheet-template',
    'odc' => 'application/vnd.oasis.opendocument.chart',
    'otc' => 'application/vnd.oasis.opendocument.chart-template',
    'odi' => 'application/vnd.oasis.opendocument.image',
    'oti' => 'application/vnd.oasis.opendocument.image-template',
    'odf' => 'application/vnd.oasis.opendocument.formula',
    'otf' => 'application/vnd.oasis.opendocument.formula-template',
    'odm' => 'application/vnd.oasis.opendocument.text-master',
    'oth' => 'application/vnd.oasis.opendocument.text-web',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xltx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.template',
    'potx' => 'application/vnd.openxmlformats-officedocument.presentationml.template',
    'ppsx' => 'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'sldx' => 'application/vnd.openxmlformats-officedocument.presentationml.slide',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'dotx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.template',
    'pages'    => 'application/x-iwork-pages-sffpages',
    'template' => 'application/x-iwork-pages-sfftemplate',
    'key' => 'application/x-iwork-keynote-sffkey',
    'kth' => 'application/x-iwork-keynote-sffkth',
    'numbers'     => 'application/x-iwork-numbers-sffnumbers',
    'nmbtemplate' => 'application/x-iwork-numbers-sfftemplate',
    'tiff' => 'image/tiff',
    'tif' => 'image/tiff',
    'jpeg' => 'image/jpeg',
    'jpg' => 'image/jpeg',
    'jpe' => 'image/jpeg',
    'dib' => 'image/bmp',
    'bmp' => 'image/bmp',
    'gif' => 'image/gif',
    'png' => 'image/png',
    'mht' => 'application/x-ms-web-archive',
    'mhtml' => 'application/x-ms-web-archive'
  }
  MIME_TYPE_FROM_EXTENSION = extns.update(MIME_TYPE_FROM_EXTENSION_OVERRIDES)

  EXTENSION_FROM_MIME_TYPE = Hash.new

  # Protect the mime type lookup, and generate the reverse direction
  MIME_TYPE_FROM_EXTENSION.each do |k,v|
    k.freeze
    v.freeze
    # Take first extension defined, so that obscure extensions don't override normal extension
    EXTENSION_FROM_MIME_TYPE[v] ||= k
  end
  MIME_TYPE_FROM_EXTENSION.freeze
  EXTENSION_FROM_MIME_TYPE.freeze

  OLD_MSOFFICE_FORMATS = {
    'application/msword' => true,
    'application/vnd.ms-excel' => true,
    'application/vnd.ms-powerpoint' => true,
    'application/vnd.visio' => true,
    'application/x-msaccess' => true,
    'application/vnd.ms-project' => true,
    'application/x-mspublisher' => true,
    'application/msonenote' => true
  }
  def self.is_msoffice_type?(mime_type)
    OLD_MSOFFICE_FORMATS.has_key?(mime_type) || mime_type =~ /\Aapplication\/vnd.openxmlformats-officedocument/
  end


  def self.type_from_extension(ext)
    MIME_TYPE_FROM_EXTENSION[ext.downcase] || 'application/octet-stream'
  end

  def self.extension_from_type(mime_type)
    EXTENSION_FROM_MIME_TYPE[mime_type]
  end

  def self.type_icon(mime_type)
    return 'image' if mime_type =~ /\Aimage\//i
    i = TYPE_ICONS[canonical_base_type(mime_type)]
    i = i.dup if i != nil
    i || 'generic'
  end

  def self.canonical_base_type(mime_type)
    /\A([^;]+)/.match(mime_type)[1].downcase
  end

  def self.correct_filename_extension(mime_type, filename)
    mime_type = (mime_type ||= 'application/octet-stream').strip
    extension = (m = /\.(\w+)\z/.match(filename)) ? m[1] : ""
    expected_extension = self.extension_from_type(self.correct_mime_type(mime_type))
    unless expected_extension
      mime_type_without_options = mime_type.split(/\s*;/)[0]
      expected_extension = self.extension_from_type(self.correct_mime_type(mime_type_without_options))
    end
    if expected_extension && (expected_extension != extension.downcase)
      filename = "#{filename}.#{expected_extension}"
    end
    filename
  end

  def self.correct_mime_type(mime_type_in, filename = nil)
    # Is it a known extension?
    if filename != nil && filename =~ /\.([^\.]+)\z/
      ext = $1.downcase
      type = MIME_TYPE_FROM_EXTENSION_OVERRIDES[ext]
      return type.dup if type != nil
    end
    # Do various corrections
    type = nil
    opts = nil
    type = $1 if mime_type_in =~ /\s*([a-zA-Z0-9\.\-]+\/[a-zA-Z0-9\.\-]+)/
    type = type.downcase if type != nil   # case insensitive, so canonicalise to lower case
    opts = $1 if mime_type_in =~ /.+?;\s*(.+?)\s*\z/
    # Did the uploader know?
    if type != nil && type == 'application/octet-stream'
      type = nil # force guess from filename
      opts = nil
    end
    # Correct type?
    correction = MIME_TYPE_CORRECTIONS[type]
    if correction != nil
      type = correction
      opts = nil  # no options, because if the type if wrong the options are unlikely to be correct
    end
    if type == nil
      # Nothing, guess from filename
      if filename != nil && filename =~ /\.(\w+)\z/
        type = MIME_TYPE_FROM_EXTENSION[$1.downcase]
      end
    end
    return 'application/octet-stream' if type == nil
    (opts == nil) ? type : "#{type}; #{opts}"
  end
end
