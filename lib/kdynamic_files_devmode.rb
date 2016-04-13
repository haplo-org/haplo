# Haplo Platform                                     http://haplo.org
# (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


module KDynamicFiles

  def self.devmode_setup
    # Make a list of all the which could change and need a reload
    all_files = Array.new
    Dir.new(CSS_SOURCE_DIR).each { |filename| all_files << "#{CSS_SOURCE_DIR}/#{filename}" }
    all_files << "#{IMAGES_SOURCE_DIR}/virtual.txt"
    Dir.new(IMAGES_SOURCE_DIR).each { |filename| all_files << "#{IMAGES_SOURCE_DIR}/#{filename}" }
    # Plugins have files too!
    Dir.glob("#{KFRAMEWORK_ROOT}/app/plugins/**/static/*").each { |n| all_files << n }
    $_kdynamic_files_all = all_files.map { |f| [f, File.mtime(f)] }
  end

  def self.devmode_check
    changed = false
    $_kdynamic_files_all.each do |filename, mtime|
      changed = true if mtime != File.mtime(filename)
    end
    changed
  end

  def self.devmode_reload
    puts "Invalidating all dynamic files..."
    Java::OrgHaploFramework::Application.allLoadedApplicationObjects().each do |japp|
      japp.invalidateAllDynamicFiles()
    end
    eval(File.open(CSS_PREPROCESS_RUBY) { |f| f.read })
    # Setup all the dynamic files again, to regenerate template functions
    self.setup
    devmode_setup
  end

end

