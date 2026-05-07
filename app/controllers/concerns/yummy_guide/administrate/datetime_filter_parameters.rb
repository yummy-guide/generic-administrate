# frozen_string_literal: true

module YummyGuide
  module Administrate
    module DatetimeFilterParameters
      extend ActiveSupport::Concern

      private

      def normalize_datetime_filter_params(filters, keys:)
        return filters if filters.blank? || !filters.respond_to?(:deep_dup)

        normalized_filters = filters.deep_dup

        Array(keys).map(&:to_s).each do |key|
          date_value = normalized_filters.delete("#{key}_date") || normalized_filters.delete("#{key}_date".to_sym)
          hour_value = normalized_filters.delete("#{key}_hour") || normalized_filters.delete("#{key}_hour".to_sym)
          minute_value = normalized_filters.delete("#{key}_minute") || normalized_filters.delete("#{key}_minute".to_sym)
          next if date_value.nil? && hour_value.nil? && minute_value.nil?

          date_value = date_value.to_s.strip
          hour_value = hour_value.to_s.strip
          minute_value = minute_value.to_s.strip

          normalized_filters[key.to_sym] =
            if date_value.blank?
              nil
            elsif hour_value.present? && minute_value.present?
              "#{date_value}T#{hour_value}:#{minute_value}"
            else
              date_value
            end
        end

        normalized_filters
      end
    end
  end
end

