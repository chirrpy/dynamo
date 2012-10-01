# TODO: We need to generalize the logic here such that we can pass in the necessary
# information to DynamicFields.dynamic_fields and have all of the other functionality
# behave properly.
#
# The `fields` call should not be hard coded, etc
#
module DynamicFields
  FIELD_NAME_PATTERN = /(.+)_field(=)?$/

  module ClassMethods
    def dynamic_fields(field_name)
      self.class_eval do
        serialize field_name, Array
      end
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def validate_dynamic_fields
    self.fields.each do |field|
      self.errors.add(:fields, field.errors) unless field.valid?
    end
  end

  def field_errors
    self.fields.each_with_object({}) do |f, h|
      h.merge! f.field_errors
    end
  end

  def fields_metadata=(fields_metadata)
    self.fields = []

    fields_metadata.each do |field_metadata|
      self.fields << CustomFieldValue.new(:metadata => field_metadata)
    end
  end

  def respond_to_missing?(sym, include_private = false)
    return super unless sym.match FIELD_NAME_PATTERN

    field_name = $1

    self.fields.find {|f| f.metadata.underscored_name == field_name}.present?
  end

  def method_missing(sym, *args, &block)
    return super unless sym.match FIELD_NAME_PATTERN

    field_name = $1
    is_setter  = $2.present?
    field      = self.fields.find {|f| f.metadata.underscored_name == field_name} || CustomFieldValue.new

    if is_setter
      field.value = args.first
    else
      field.value
    end
  end

  def attributes=(attrs)
    field_attributes = attrs.delete('fields') {{}}

    fields.each do |field|
      field.set_value_from_attributes field_attributes
      fields_will_change! if field.changed?
    end

    super
  end
end
