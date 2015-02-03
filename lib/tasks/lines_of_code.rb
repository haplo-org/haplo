# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


DIRS = [
    ['Server side', ['framework', 'app', 'lib', 'java/com']],
    ['Deployment', ['deploy']],
    ['Client side', ['static']],
    ['Tests', ['test']]
  ]

Language = Struct.new(:name, :ext, :clean, :is_comment)

LANGUAGES = [
    Language.new('Ruby', 'rb', nil, /\A\s*\#/),
    Language.new('Java', 'java', /\/\*.+?\*\//m, /\A\s*\/\//),
    Language.new('C', 'c', /\/\*.+?\*\//m, /\A\s*\/\//),
    Language.new('C++', 'cpp', /\/\*.+?\*\//m, /\A\s*\/\//),
    Language.new('ERB Views', 'erb', nil, /\A NO LINE COMMENTS/),
    Language.new('HAML Views', 'haml', nil, /\A NO LINE COMMENTS/),
    Language.new('JavaScript', 'js', /\/\*.+?\*\//m, /\A\s*\/\//),
    Language.new('CSS', 'css', /\/\*.+?\*\//m, /\A NO LINE COMMENTS/)
  ]

SKIP = {
    'static/javascripts/underscore.js' => true,
    'static/javascripts/jquery.js' => true,
    'static/javascripts/controls.js' => true,
    'static/javascripts/dragdrop.js' => true,
    'static/javascripts/effects.js' => true,
    'static/javascripts/prototype.js' => true
  }

counts = []

DIRS.each do |location|
  where, dirs = location

  cs = LANGUAGES.map do |language|
    count = 0
    count_c = 0
    dirs.each do |d|
      Dir.glob("#{d}/**/*.#{language.ext}").each do |filename|
        next if SKIP.has_key?(filename) || filename =~ /\/vendor\// || filename =~ /\/thirdparty\// || filename =~ /\Adeploy\/javascript/
        File.open(filename) do |f|
          file = f.read
          file.gsub!(language.clean, '') if language.clean != nil
          file.split(/[\n\r]+/).each do |line|
            next unless line =~ /\S/
            count_c += 1
            next if line =~ language.is_comment
            count += 1
          end
        end
      end
    end
    [language.name, count, count_c]
  end

  counts << [where, cs]

end

totals = Hash.new

puts "Count in brackets includes comments"

counts.each do |where, counts|
  puts where
  counts.each do |nm, c, cs|
    next if c == 0
    puts "  #{sprintf('%12s', nm)}  #{c} (#{cs})"
    n = totals[nm] ||= [0,0]
    totals[nm] = [n.first+c,n.last+cs]
  end
end

puts "TOTAL"
total = 0
total_c = 0
totals.each do |nm, c|
  puts "  #{sprintf('%12s', nm)}  #{c.first} (#{c.last})"
  total += c.first
  total_c += c.last
end

puts "ALL TOTAL: #{total} (#{total_c})"

