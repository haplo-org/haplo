# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.



class KObjRef
  include Java::OrgHaploJsinterfaceApp::AppObjRef

  attr_reader :obj_id
  # NOTE: k_typecode defined in kconstants.rb to avoid circular ref

  VALIDATE_REGEXP = /\A[0-9qvwxyz]+\z/

  def initialize(obj_id)
    @obj_id = case obj_id
    when Integer
      obj_id.to_i
    when KObjRef
      obj_id.obj_id
    else
      raise "Bad type for obj_id"
    end
    raise "Bad obj_id #{@obj_id}" if @obj_id < 0
  end

  def to_i
    @obj_id
  end

  def to_s
    to_presentation
  end

  # A "desc" is an integer representation of an objref which refers to an attribute
  # or qualifier. They're stored in KObjects using descs rather than KObjRefs for
  # efficiency.
  # The name is for "historical reasons", and clashes a bit with things like
  # "attribute descriptor" objects in the schema.
  alias :to_desc :obj_id
  def self.from_desc(desc)
    raise "Bad desc" unless desc.kind_of?(Integer) && desc >= 0
    KObjRef.new(desc.to_i)
  end

  # Conversion to and from the presentation style
  def to_presentation
    @obj_id.to_s(16).tr('abcdef','qvwxyz')
  end
  def self.from_presentation(str)
    return nil unless str =~ VALIDATE_REGEXP
    KObjRef.new(str.tr('qvwxyz','abcdef').to_i(16))
  end

  # To JSON
  def to_json(*a)
    %Q!"#{to_presentation}"!
  end

  # Standard operators
  def ==(other)
    other.kind_of?(KObjRef) && other != nil && @obj_id == other.to_i
  end
  def eql?(other)
    other.kind_of?(KObjRef) && other != nil && @obj_id == other.to_i
  end
  def hash
    @obj_id.hash
  end
  def <=>(other)
    @obj_id <=> other.to_i
  end
end

# Workaround for http://jira.codehaus.org/browse/JRUBY-5317
Java::OrgHaploJsinterfaceApp::JRuby5317Workaround.appObjRef(KObjRef.new(1))

