# frozen_string_literal: true

require "administrate/field/text"
require "json"

module YummyGuide
  module Administrate
    module Fields
      class JsonPrettyField < ::Administrate::Field::Text
        def self.field_type
          "yummy_guide_administrate/json_pretty_field"
        end

        def to_s
          return if data.blank?

          if data.is_a?(String)
            JSON.pretty_generate(JSON.parse(data))
          else
            JSON.pretty_generate(data.as_json)
          end
        rescue JSON::ParserError, TypeError
          data.to_s
        end
      end
    end
  end
end

