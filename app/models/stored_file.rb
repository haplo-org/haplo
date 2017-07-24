# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Represents an uploaded file

class StoredFile < ActiveRecord::Base
  has_many :file_cache_entries, :dependent => :destroy  # will delete files from disk
  after_create :send_create_notification
  after_create :do_background_thumbnailing
  after_destroy :delete_file_from_disk

  # This algorithm choosen (in 2014) because:
  #  * SHA-1 is old, a bit short, and has structural problems
  #  * SHA-256 is based on a well understood SHA-1, so far hasn't had any significant issues found, and is a reasonable length
  #  * SHA-3 family is too new and novel
  #  * It's relatively easy to change things in the future
  #  * It's not used for security access control
  # We don't encode the algorithm in the identifier because it'll be easy to add that later if we need multiple algorithm support.
  FILE_DIGEST_ALGORITHM = 'SHA-256'.freeze
  FILE_DIGEST_HEX_VALIDATE_REGEXP = /\A[a-f0-9]{64}\z/

  # Create directories so the group can read them (for backup user doing offsite backups by rsync)
  DIRECTORY_CREATION_MODE = 0750

  THUMBNAIL_FORMAT_PNG = 0
  THUMBNAIL_FORMAT_GIF = 1
  THUMBNAIL_FORMAT_JPEG = 2
  THUMBNAIL_FORMAT__LOOKUP = {
    'png' => THUMBNAIL_FORMAT_PNG,
    'gif' => THUMBNAIL_FORMAT_GIF,
    'jpg' => THUMBNAIL_FORMAT_JPEG,
    'jpeg' => THUMBNAIL_FORMAT_JPEG
  }
  THUMBNAIL_FORMAT_TO_EXTENSION = { # IMPORTANT - extensions be able to build valid image/X MIME types
    THUMBNAIL_FORMAT_PNG => 'png',
    THUMBNAIL_FORMAT_GIF => 'gif',
    THUMBNAIL_FORMAT_JPEG => 'jpeg'
  }

  # ----------------------------------------------------------------------------------------------------------------

  def self.from_identifier(identifier)
    where(:digest => identifier.digest, :size => identifier.size).first
  end

  def self.from_digest(digest)  # not really recommended, for JS support
    where(:digest => digest.to_s).first
  end

  def self.from_digest_and_size(digest, size)
    where(:digest => digest.to_s, :size => size.to_i).first
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   File creation
  # ----------------------------------------------------------------------------------------------------------------

  # Create new object from an upload; may return nil, otherwise object will have been saved
  def self.from_upload(upload, options = nil)
    return nil if upload == nil || upload.is_a?(String) || !(upload.wasUploaded())
    move_file_into_store(
      upload.getSavedPathname(),
      upload.getFilename(),
      upload.getMIMEType(),
      upload.getDigest(),
      options
    )
  end

  # Create a new object given a file. The store will then own the file, moving the file on disk into the store.
  def self.move_file_into_store(file_pathname, given_filename, mime_type, file_digest = nil, options = nil)
    file_size = File.size(file_pathname)
    file_digest = Digest::SHA256.file(file_pathname).hexdigest.encode(Encoding::UTF_8) if file_digest == nil
    raise "Didn't get digest" unless file_digest.length > 10
    raise "Bad digest" unless file_digest =~ FILE_DIGEST_HEX_VALIDATE_REGEXP

    # Check expected hash and size?
    if options != nil
      checks_passed = true
      checks_passed = false if options.has_key?(:expected_size) && file_size != options[:expected_size].to_i
      checks_passed = false if options.has_key?(:expected_hash) && file_digest != options[:expected_hash]
      raise "File didn't match expected hash/size" unless checks_passed
    end

    # Create stored file, checking for existing file
    file = nil
    StoredFile.transaction do
      file = StoredFile.find(:first, :conditions => {:digest => file_digest, :size => file_size})
      if file
        # Already exists. Do a very basic check on the file on disc, as we're going to throw away the uploaded file
        unless File.size(file.disk_pathname) == file_size
          raise "User uploaded a duplicate by file size doesn't match -- corrupt file store?"
        end
        # Notification for audit trail
        KNotificationCentre.notify(:file_store, :new_file, file, :duplicate)
        KApp.logger.info("User uploaded file duplicating existing store file with digest #{file_digest} and size #{file_size}")
      else
        file = StoredFile.new
        file.upload_filename = given_filename
        file.mime_type = KMIMETypes.correct_mime_type(mime_type, given_filename)
        file.size = file_size
        file.digest = file_digest

        # Move the file into place
        file.ensure_directory_exists
        File.chmod(0640, file_pathname) # change permission for the backup user
        FileUtils.mv(file_pathname, file.disk_pathname)

        file.save!
      end
    end
    file
  end

  def send_create_notification
    KNotificationCentre.notify(:file_store, :new_file, self, :create)
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   Render text -- possible truncated plain text equivalent, for rendering excerpts
  # ----------------------------------------------------------------------------------------------------------------

  def render_text
    return nil unless self.render_text_chars
    pathname = self.disk_pathname_render_text
    rt = nil
    begin
      File.open(pathname) do |f|
        rt = Zlib::Inflate.inflate(f.read)
        rt.force_encoding(Encoding::UTF_8)
      end
    rescue => e
      KApp.logger.error("Exception when attempting to load rendering text for stored file #{self.digest} (id #{self.id})")
      KApp.logger.log_exception(e)
    end
    rt
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   Secret generation for client side round trips, to avoid users being able to obtains files knowing just digest
  # ----------------------------------------------------------------------------------------------------------------

  # FILE TODO: Better tests for file secrets and confirmation they're checked in editor and forms
  def self.generate_secret(digest, size)
    key = KApp.global(:file_secret_key)
    raise "Bad :file_secret_key app global" unless key && key.length >= 64
    HMAC::SHA256.sign(key, "#{digest},#{size},#{KApp.current_application}")
  end
  def self.compare_secret(a, b)
    a && a.kind_of?(String) && a.length > 16 && b && b.kind_of?(String) && b.length > 16 && (Digest::SHA256.hexdigest(a) == Digest::SHA256.hexdigest(b))
  end

  def generate_secret
    StoredFile.generate_secret(self.digest, self.size)
  end
  def compare_secret_to(given_secret)
    StoredFile.compare_secret(self.generate_secret, given_secret)
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   Storage on disk
  # ----------------------------------------------------------------------------------------------------------------

  # And the root on the disc
  def self.disk_root
    "#{KFILESTORE_PATH}/#{KApp.current_application}/store"
  end

  # Store initialisation
  def self.init_store_on_disc_for_app(app_id)
    raise "Bad app id" unless app_id.kind_of?(Integer)  # check
    ['store','cache','temp'].each do |dirname|
      path = "#{KFILESTORE_PATH}/#{app_id}/#{dirname}"
      puts "WARNING: #{path} already exists" if File.exists?(path)
      unless File.directory?(path)
        FileUtils.mkdir_p(path, :mode => DIRECTORY_CREATION_MODE)
      end
    end
  end

  def ensure_directory_exists
    pathname = self.disk_pathname
    dirname = File.dirname(pathname)
    unless File.exists?(dirname)
      FileUtils.mkdir_p(dirname, :mode => StoredFile::DIRECTORY_CREATION_MODE)
    end
    raise "Unexpected file where a directory was expected for #{dirname}" unless File.directory?(dirname)
  end

  # Clean up files when deleted
  # after_destroy
  def delete_file_from_disk
    pathname = self.disk_pathname
    if File.exists?(pathname)
      File.unlink(pathname)
    end
    thumbnail_pathname = self.disk_pathname_thumbnail
    if File.exists?(thumbnail_pathname)
      File.unlink(thumbnail_pathname)
    end
    render_text_pathname = self.disk_pathname_render_text
    if File.exists?(render_text_pathname)
      File.unlink(render_text_pathname)
    end
  end

  def disk_pathname
    raise "unexpected digest format" unless self.digest =~ /\A([a-f0-9]{4})([a-f0-9]{4})/
    "#{KFILESTORE_PATH}/#{KApp.current_application}/store/#{$1}/#{$2}/#{self.digest}-#{self.size}"
  end

  def disk_pathname_thumbnail
    disk_pathname + "_t"
  end

  def disk_pathname_render_text
    disk_pathname + "_r"
  end

  def self.storage_space_used
    calculate(:sum, :size)
  end

  # ----------------------------------------------------------------------------------------------------------------
  #   File info and thumbnailing
  # ----------------------------------------------------------------------------------------------------------------

  # For compatibility with KFileIdentifier
  def presentation_filename
    self.upload_filename
  end

  def dimensions
    units = self.dimensions_units
    return nil if units == nil
    KFileTransform::Dimensions.new(self.dimensions_w, self.dimensions_h, units.to_sym)
  end

  ThumbnailInfo = Struct.new(:width, :height, :urlpath)
  THUMBNAIL_AUDIO = ThumbnailInfo.new(47, 47, '/images/preview_audio.gif').freeze
  THUMBNAIL_VIDEO = ThumbnailInfo.new(47, 47, '/images/preview_video.gif').freeze
  def thumbnail
    format = self.thumbnail_format
    if format == nil
      mime_type = self.mime_type
      return THUMBNAIL_AUDIO if mime_type =~ /\Aaudio\//i
      return THUMBNAIL_VIDEO if mime_type =~ /\Avideo\//i
      return nil
    end
    ThumbnailInfo.new(self.thumbnail_w, self.thumbnail_h)
  end

  def thumbnail_mime_type
    "image/#{THUMBNAIL_FORMAT_TO_EXTENSION[self.thumbnail_format]}"
  end

  def set_dimensions(w, h, units)
    self.dimensions_w = w
    self.dimensions_h = h
    self.dimensions_units = units
  end
  def set_thumbnail(w, h, format)
    self.thumbnail_w = w
    self.thumbnail_h = h
    self.thumbnail_format = format
  end

  # ----------------------------------------------------------------------------------------------------------------

  # Post-create callback to get the job - in the same transaction
  # after_create
  def do_background_thumbnailing
    PostCreate.new(self.id).submit
  end

  class PostCreate < KJob
    def initialize(id)
      @stored_file_id = id
    end
    def run(context)
      # Ask file transformation service to add the extra info
      stored_file = StoredFile.find(@stored_file_id)
      KFileTransform.set_image_dimensions_and_make_thumbnail(stored_file)
      KFileTransform.set_render_text(stored_file)
    end
  end

  # ----------------------------------------------------------------------------------------------------------------

  # JavaScript interface
  KActiveRecordJavaInterface.make_date_methods(self, :created_at, :jsGetCreatedAt)
  def jsGetBasename
    self.upload_filename.gsub(/\.[^\.]+\z/,'')
  end

  def jsGetTagsAsJson()
    hstore = read_attribute('tags')
    hstore ? JSON.generate(PgHstore.parse_hstore(hstore)) : nil
  end

  def jsUpdateTags(changes)
    # WARNING: Generates SQL directly for easy atomic updates, careful with quoting if modifying
    set = []
    delete = []
    JSON.parse(changes).each do |k,v|
      if v.nil?
        delete.push(k)
      else
        set.push([k,v])
      end
    end
    return if set.empty? && delete.empty?
    new_value = "COALESCE(tags,''::hstore)"
    unless delete.empty?
      new_value = "(#{new_value} - ARRAY[#{delete.map { |k| PGconn.quote(k) } .join(',')}])"
    end
    unless set.empty?
      new_value << ' || hstore(ARRAY['
      new_value << set.map do |k,v|
        "[#{PGconn.quote(k)},#{PGconn.quote(v)}]"
      end .join(',')
      new_value << '])'
    end
    sql = "UPDATE stored_files SET tags = (#{new_value}) WHERE id=#{self.id.to_i}";
    KApp.get_pg_database.exec(sql)
    self.reload
  end

end
