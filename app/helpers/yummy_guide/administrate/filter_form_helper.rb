# frozen_string_literal: true

module YummyGuide
  module Administrate
    module FilterFormHelper
      def yummy_guide_administrate_filter_current_values(raw_values)
        values =
          if raw_values.respond_to?(:to_unsafe_h)
            raw_values.to_unsafe_h
          elsif raw_values.respond_to?(:to_h)
            raw_values.to_h
          else
            raw_values || {}
          end

        values.deep_stringify_keys
      end

      def yummy_guide_administrate_filter_hour_options
        @yummy_guide_administrate_filter_hour_options ||= [["", ""]] + (0..23).map { |hour| [format("%02d", hour), format("%02d", hour)] }
      end

      def yummy_guide_administrate_filter_minute_options
        @yummy_guide_administrate_filter_minute_options ||= [["", ""], ["00", "00"], ["30", "30"], ["59", "59"]]
      end

      def yummy_guide_administrate_datetime_filter_parts(value, end_of_day: false)
        raw_value = value.to_s.strip

        if raw_value.blank?
          { date: "", hour: "", minute: "" }
        elsif raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          {
            date: raw_value,
            hour: (end_of_day ? "23" : "00"),
            minute: (end_of_day ? "59" : "00")
          }
        else
          parsed = Time.zone.parse(raw_value)

          if parsed.present?
            {
              date: parsed.strftime("%Y-%m-%d"),
              hour: parsed.strftime("%H"),
              minute: parsed.strftime("%M")
            }
          else
            { date: "", hour: "", minute: "" }
          end
        end
      end

      def yummy_guide_administrate_datetime_filter_combined_value(parts)
        if parts[:date].blank?
          ""
        elsif parts[:hour].present? && parts[:minute].present?
          "#{parts[:date]}T#{parts[:hour]}:#{parts[:minute]}"
        else
          parts[:date]
        end
      end

      def yummy_guide_administrate_checkbox_group_options(options, label_method: nil, value_method: nil)
        Array(options).map do |option|
          if option.is_a?(Array) && option.size == 2
            option
          elsif label_method.present? || value_method.present?
            [
              option.public_send(label_method || :to_s),
              option.public_send(value_method || :id)
            ]
          else
            [option, option]
          end
        end
      end
    end
  end
end

