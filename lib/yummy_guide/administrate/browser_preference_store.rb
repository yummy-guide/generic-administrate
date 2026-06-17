# frozen_string_literal: true

require "json"

module YummyGuide
  module Administrate
    class BrowserPreferenceStore
      TTL_SECONDS = 30 * 24 * 60 * 60
      KEY_PREFIX = "yummy_guide_administrate:admin_browser_preferences:v1"
      MIN_NAVIGATION_WIDTH = 25
      MAX_NAVIGATION_WIDTH = 250
      MIN_COLUMN_WIDTH = 48
      MAX_COLUMN_WIDTH = 5000
      MAX_SCOPE_LENGTH = 200
      MAX_COLUMN_ID_LENGTH = 200

      class InvalidPreference < StandardError; end
      class RedisUnavailable < StandardError; end

      attr_reader :redis, :key_prefix

      def initialize(redis: nil, key_prefix: KEY_PREFIX)
        @redis = redis
        @key_prefix = key_prefix
      end

      def fetch(browser_id)
        return empty_state if browser_id.blank?

        with_redis do |client|
          raw_value = client.get(key_for(browser_id))
          client.expire(key_for(browser_id), TTL_SECONDS) if raw_value.present?
          normalize_state(parse_state(raw_value))
        end
      rescue RedisUnavailable
        raise
      rescue StandardError => e
        raise RedisUnavailable, e.message
      end

      def update(browser_id, attributes)
        raise InvalidPreference, "browser_id is required" if browser_id.blank?

        with_redis do |client|
          state = normalize_state(parse_state(client.get(key_for(browser_id))))
          apply_update(state, attributes.to_h)
          client.set(key_for(browser_id), JSON.generate(state), ex: TTL_SECONDS)
          state
        end
      rescue InvalidPreference, RedisUnavailable
        raise
      rescue StandardError => e
        raise RedisUnavailable, e.message
      end

      private

      def with_redis
        client = redis || default_redis
        raise RedisUnavailable, "Redis client is not configured" if client.blank?

        if client.respond_to?(:with) && !client.respond_to?(:get)
          client.with { |pooled_client| yield pooled_client }
        else
          yield client
        end
      end

      def default_redis
        configured = YummyGuide::Administrate.admin_browser_preferences_redis
        return configured.call if configured.respond_to?(:call)
        return configured if configured.present?
        return $redis if defined?($redis) && $redis.present?
        return unless defined?(::Redis)

        @default_redis ||= ::Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0"))
      end

      def key_for(browser_id)
        "#{key_prefix}:#{browser_id}"
      end

      def parse_state(raw_value)
        return empty_state if raw_value.blank?

        JSON.parse(raw_value)
      rescue JSON::ParserError
        empty_state
      end

      def empty_state
        {
          "navigation_width" => nil,
          "column_widths" => {}
        }
      end

      def normalize_state(raw_state)
        state = raw_state.is_a?(Hash) ? raw_state : {}
        column_widths = state["column_widths"].is_a?(Hash) ? state["column_widths"] : {}

        {
          "navigation_width" => normalize_width(
            state["navigation_width"],
            min: MIN_NAVIGATION_WIDTH,
            max: MAX_NAVIGATION_WIDTH,
            allow_blank: true
          ),
          "column_widths" => normalize_column_widths(column_widths)
        }
      end

      def normalize_column_widths(column_widths)
        column_widths.each_with_object({}) do |(scope, widths), normalized|
          next unless valid_identifier?(scope, max_length: MAX_SCOPE_LENGTH)
          next unless widths.is_a?(Hash)

          normalized_widths = widths.each_with_object({}) do |(column_id, width), normalized_columns|
            next unless valid_identifier?(column_id, max_length: MAX_COLUMN_ID_LENGTH)

            normalized_width = normalize_width(width, min: MIN_COLUMN_WIDTH, max: MAX_COLUMN_WIDTH, allow_blank: true)
            normalized_columns[column_id.to_s] = normalized_width if normalized_width
          end
          normalized[scope.to_s] = normalized_widths if normalized_widths.present?
        end
      end

      def apply_update(state, attributes)
        preference = attributes["preference"].presence || attributes[:preference].presence

        case preference
        when "navigation_width"
          update_navigation_width(state, attributes)
        when "column_width"
          update_column_width(state, attributes)
        else
          raise InvalidPreference, "unknown preference"
        end
      end

      def update_navigation_width(state, attributes)
        width = normalize_width(
          attributes["width"] || attributes[:width],
          min: MIN_NAVIGATION_WIDTH,
          max: MAX_NAVIGATION_WIDTH,
          allow_blank: true
        )
        state["navigation_width"] = width
      end

      def update_column_width(state, attributes)
        scope = attributes["scope"].presence || attributes[:scope].presence
        column_id = attributes["column_id"].presence || attributes[:column_id].presence
        raise InvalidPreference, "scope is invalid" unless valid_identifier?(scope, max_length: MAX_SCOPE_LENGTH)
        raise InvalidPreference, "column_id is invalid" unless valid_identifier?(column_id, max_length: MAX_COLUMN_ID_LENGTH)

        width = normalize_width(
          attributes["width"] || attributes[:width],
          min: MIN_COLUMN_WIDTH,
          max: MAX_COLUMN_WIDTH,
          allow_blank: true
        )
        widths = state["column_widths"][scope.to_s] ||= {}

        if width
          widths[column_id.to_s] = width
        else
          widths.delete(column_id.to_s)
          state["column_widths"].delete(scope.to_s) if widths.empty?
        end
      end

      def normalize_width(value, min:, max:, allow_blank:)
        return nil if allow_blank && value.blank?

        width = Float(value)
        raise InvalidPreference, "width is invalid" unless width.finite?
        raise InvalidPreference, "width is out of range" if width < min || width > max

        (width * 1000).round / 1000.0
      rescue ArgumentError, TypeError
        raise InvalidPreference, "width is invalid"
      end

      def valid_identifier?(value, max_length:)
        string_value = value.to_s
        string_value.present? && string_value.length <= max_length && string_value.match?(/\A[-.\/:_a-zA-Z0-9]+\z/)
      end
    end
  end
end
