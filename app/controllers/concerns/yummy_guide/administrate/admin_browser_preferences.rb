# frozen_string_literal: true

require "securerandom"

module YummyGuide
  module Administrate
    module AdminBrowserPreferences
      extend ActiveSupport::Concern

      COOKIE_NAME = :yummy_guide_admin_browser_id
      COOKIE_TTL = 30.days

      included do
        before_action :ensure_yummy_guide_administrate_admin_browser_id

        helper_method :yummy_guide_administrate_admin_browser_preferences_style
        helper_method :yummy_guide_administrate_admin_browser_column_widths
      end

      def update_yummy_guide_administrate_browser_preference
        yummy_guide_administrate_browser_preference_store.update(
          yummy_guide_administrate_admin_browser_id,
          yummy_guide_administrate_browser_preference_params
        )

        head :no_content
      rescue YummyGuide::Administrate::BrowserPreferenceStore::InvalidPreference => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue YummyGuide::Administrate::BrowserPreferenceStore::RedisUnavailable => e
        Rails.logger.warn("Admin browser preference Redis unavailable: #{e.message}")
        render json: { error: "preference store is unavailable" }, status: :service_unavailable
      end

      def yummy_guide_administrate_admin_browser_preferences
        @yummy_guide_administrate_admin_browser_preferences ||=
          yummy_guide_administrate_browser_preference_store.fetch(yummy_guide_administrate_admin_browser_id)
      rescue YummyGuide::Administrate::BrowserPreferenceStore::RedisUnavailable => e
        Rails.logger.warn("Admin browser preference Redis unavailable: #{e.message}")
        @yummy_guide_administrate_admin_browser_preferences = {
          "navigation_width" => nil,
          "column_widths" => {}
        }
      end

      def yummy_guide_administrate_admin_browser_preferences_style
        width = yummy_guide_administrate_admin_browser_preferences["navigation_width"]
        return "" if width.blank?

        "--admin-navigation-width: #{yummy_guide_administrate_css_pixel_value(width)}"
      end

      def yummy_guide_administrate_admin_browser_column_widths(scope)
        return {} if scope.blank?

        yummy_guide_administrate_admin_browser_preferences.dig("column_widths", scope.to_s) || {}
      end

      private

      def ensure_yummy_guide_administrate_admin_browser_id
        id = yummy_guide_administrate_admin_browser_id
        cookies.signed[COOKIE_NAME] = {
          value: id,
          expires: COOKIE_TTL.from_now,
          httponly: true,
          secure: request.ssl? || Rails.env.production?,
          same_site: :lax
        }
      end

      def yummy_guide_administrate_admin_browser_id
        @yummy_guide_administrate_admin_browser_id ||= begin
          existing_id = cookies.signed[COOKIE_NAME].presence
          existing_id || SecureRandom.uuid
        end
      end

      def yummy_guide_administrate_browser_preference_store
        @yummy_guide_administrate_browser_preference_store ||= YummyGuide::Administrate::BrowserPreferenceStore.new
      end

      def yummy_guide_administrate_browser_preference_params
        params.permit(:preference, :width, :scope, :column_id)
      end

      def yummy_guide_administrate_css_pixel_value(value)
        numeric_value = value.to_f
        rounded_value = (numeric_value * 1000).round / 1000.0
        rounded_value == rounded_value.to_i ? "#{rounded_value.to_i}px" : "#{rounded_value}px"
      end
    end
  end
end
