# frozen_string_literal: true

module Yg
  module Administrate
    module DefaultSorting
      extend ActiveSupport::Concern

      def default_sorting_attribute
        dashboard_sorting_value(:default_sorting_attribute) || super
      end

      def default_sorting_direction
        dashboard_sorting_value(:default_sorting_direction) || super
      end

      private

      def sorting_requested?
        order_present?(params) || sorting_param_keys.any? { |key| order_present?(params[key]) }
      end

      def dashboard_sorting_value(method_name)
        current_dashboard = dashboard
        return unless current_dashboard.respond_to?(method_name)

        current_dashboard.public_send(method_name)
      end

      def sorting_param_keys
        [
          (resource_name if respond_to?(:resource_name, true)),
          (resource_name.to_sym if respond_to?(:resource_name, true) && resource_name.present?),
          controller_name.singularize,
          controller_name.singularize.to_sym
        ].compact.uniq
      end

      def order_present?(value)
        return false unless value.is_a?(ActionController::Parameters) || value.is_a?(Hash)

        value[:order].present? || value["order"].present?
      end
    end
  end
end

