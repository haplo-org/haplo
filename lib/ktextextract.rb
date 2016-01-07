# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Interface to the Java com.oneis.text.extract.* classes.

module KTextExtract

  # Maximum file size for extracting text
  MAX_EXTRACT_FILE_SIZE = (1024*1024*128) # 128MB
  # Copy over the exceptions from KFileTransform (see notes there about processing limits)
  MAX_EXTRACT_FILE_SIZE_EXCEPTIONS = KFileTransform::MAX_TRANSFORM_FILE_SIZE_EXCEPTIONS
  raise "Expected exceptions" if MAX_EXTRACT_FILE_SIZE_EXCEPTIONS.empty?

  # Could terms be extracted from the given mime type / file?
  def self.can_extract_terms?(what)
    mime_type = case what
    when String
      what
    when StoredFile, KIdentifierFile
      what.mime_type
    else
      raise "Bad input to KTextExtract.can_extract_terms?"
    end
    input_mime_type = KMIMETypes.canonical_base_type(mime_type)
    (OP_CLASSES.has_key?(input_mime_type) || input_mime_type =~ KFileTransform::OPENOFFICE_MIME_TYPE_REGEXP) ? true : false
  end

  OP_CLASSES = {
    'application/rtf' => Java::ComOneisTextExtract::RTF,
    'text/html' => Java::ComOneisTextExtract::HTML,
    'text/plain' => Java::ComOneisTextExtract::Text
  }
  KFileTransform::MSOFFICE_MIME_TYPES.each { |t| OP_CLASSES[t] = Java::ComOneisTextExtract::MSOffice }
  KFileTransform::IWORK_MIME_TYPES.each { |t| OP_CLASSES[t] = Java::ComOneisTextExtract::IWorkSFF }
  def self.register_op_class(mime_type, java_class)
    OP_CLASSES[mime_type] = java_class
  end
  KNotificationCentre.when(:server, :starting) { OP_CLASSES.freeze }

  # Make the Java operation which will extract the text
  def self.make_extraction_operation(filename, mime_type)
    m = KMIMETypes.canonical_base_type(mime_type)
    c = OP_CLASSES[m]
    c = Java::ComOneisTextExtract::OpenOffice if c == nil && m =~ KFileTransform::OPENOFFICE_MIME_TYPE_REGEXP
    (c == nil) ? nil : c.new(filename)
  end

  def self.max_file_size_for_mime_type(mime_type)
    MAX_EXTRACT_FILE_SIZE_EXCEPTIONS[mime_type] || MAX_EXTRACT_FILE_SIZE
  end

  # Extract the terms from a random file
  def self.extract_terms(filename, mime_type)
    return nil if File.size(filename) > max_file_size_for_mime_type(mime_type) # protect from parsing huge files
    op = self.make_extraction_operation(filename, mime_type)
    return nil if op == nil
    result = nil
    begin
      op.perform()
      result = op.getOutput()
    rescue => e
      KApp.logger.error("Error extracting text from #{filename} (#{mime_type})")
      KApp.logger.log_exception(e)
    end
    result
  end

  # Extract terms, given a StoredFile
  def self.extract_from(stored_file)
    extract_terms(stored_file.disk_pathname, stored_file.mime_type)
  end

end

