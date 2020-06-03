# frozen_string_literal: true

# Haplo Platform                                    https://haplo.org
# (c) Haplo Services Ltd 2006 - 2020            https://www.haplo.com
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Represents the transfer of attributes from a non-validated source to the Record object

class MiniORM::Transfer

  def initialize(record)
    @record = record
    @params = {}
  end

  # params has String keys
  def from_params(params)
    @params = params
    self
  end

  def read_attribute(attribute)
    key = attribute.to_s # attributes defined as Symbols, but @params has String keys
    if @params.has_key?(key)
      @params[key]
    else
      # Check it's an attribute defined for transfer
      raise "attribute '#{attribute}' not defined for transfer" unless self.class.class_variable_get(:@@allow_attribute_read).include?(attribute)
      @record.__send__(attribute)
    end
  end

  def as_new_record
    # Set an empty Errors object so a form for a new record doesn't show errors
    @errors = Errors.new
    self
  end

  def errors
    @errors ||= self._validate
  end

  def apply!
    raise "Data did not validate" unless self.errors.empty?
    apply_without_validation!
  end

  def apply_without_validation!
    text_attribute_set_method = self.class.class_variable_get(:@@text_attribute_set_method)
    self.class.class_variable_get(:@@text_attributes).each do |f|
      key = f.to_s
      if @params.has_key?(key)
        @record.__send__(text_attribute_set_method[f], @params[key])
      end
    end
    self
  end

  # -------------------------------------------------------------------------

  def self.transfer
    self.class_variable_set(:@@allow_attribute_read, [])
    text_attributes = self.class_variable_set(:@@text_attributes, [])
    validations = self.class_variable_set(:@@validations, [])
    yield self
    text_attribute_set_method = self.class_variable_set(:@@text_attribute_set_method, {})
    text_attributes.each { |f| text_attribute_set_method[f] = "#{f}=".to_sym }
  end

  def self.text_attributes(*attributes)
    self.class_variable_get(:@@text_attributes).concat attributes
    self.class_variable_get(:@@allow_attribute_read).concat attributes
  end

  def self.allow_attribute_read(*attributes)
    self.class_variable_get(:@@allow_attribute_read).concat attributes
  end

  def self.validate_presence_of(*attributes)
    _add_validations(attributes) { |f| ValidatePresenceOf.new(f) }
  end

  def self.validate_email_format(*attributes)
    _add_validations(attributes) { |f| ValidateEmailFormat.new(f) }
  end

  def self.validate(*attributes, &block)
    _add_validations(attributes) { |f| ValidateGeneric.new(f, block) }
  end

  def self._add_validations(attributes)
    validations = self.class_variable_get(:@@validations)
    attributes.each do |f|
      validations << yield(f)
    end
    self
  end

  # -------------------------------------------------------------------------

  def _validate
    errors = Errors.new
    self.class.class_variable_get(:@@validations).each do |validation|
      validation.validate(errors, @record, self)
    end
    errors
  end

  class Errors
    def initialize
      @errors = {}
    end
    def add(attribute, message)
      m = @errors[attribute] ||= []
      m << message
    end
    def empty?
      @errors.empty?
    end
    def [](param)
      @errors[param] || []
    end
    def full_messages
      messages = []
      @errors.each do |attribute, attribute_messages|
        attribute_readable = attribute.to_s.gsub('_',' ')
        attribute_readable[0] = attribute_readable[0].upcase
        attribute_messages.each do |message|
          messages << "#{attribute_readable} #{message}"
        end
      end
      messages
    end
  end

  # -------------------------------------------------------------------------

  class Validation
    def initialize(attribute)
      @attribute = attribute
    end
    def validate(errors, record, transfer)
      validate_attribute(errors, record, transfer.read_attribute(@attribute))
    end
  end

  class ValidatePresenceOf < Validation
    def validate_attribute(errors, record, value)
      if value.nil? || value.empty?
        errors.add(@attribute, "must not be empty")
      end
    end
  end

  class ValidateEmailFormat < Validation
    def validate_attribute(errors, record, value)
      if value && !value.empty? && value !~ K_EMAIL_VALIDATION_REGEX
        errors.add(@attribute, "must be a valid email address")
      end
    end
  end

  class ValidateGeneric < Validation
    def initialize(attribute, block)
      super(attribute)
      @block = block
    end
    def validate_attribute(errors, record, value)
      @block.call(errors, record, @attribute, value)
    end
  end

end
