# frozen_string_literal: true

module YummyGuide
  module Administrate
    module NumberInputHelper
      NUMBER_INPUT_CONTROL_OPTIONS = %i[type min max step in within].freeze

      def number_field(object_name, method, options = {})
        text_field(object_name, method, yummy_guide_administrate_number_input_options(options))
      end

      def number_field_tag(name, value = nil, options = {})
        return super if yummy_guide_administrate_range_input?(options)

        text_field_tag(name, value, yummy_guide_administrate_number_input_options(options))
      end

      private

      def yummy_guide_administrate_range_input?(options)
        options[:type].to_s == "range" || options["type"].to_s == "range"
      end

      def yummy_guide_administrate_number_input_options(options)
        options = options.to_h.deep_dup

        NUMBER_INPUT_CONTROL_OPTIONS.each do |option|
          options.delete(option)
          options.delete(option.to_s)
        end

        options[:inputmode] ||= "decimal"
        options
      end
    end
  end
end
