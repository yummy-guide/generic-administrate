# frozen_string_literal: true

module Yg
  module Administrate
    module Fields
      class VersionItemField < ::Administrate::Field::Base
        def self.field_type
          "yg_administrate/version_item_field"
        end

        def target_resource
          @target_resource ||= resolve_target_resource
        end

        def label
          target = target_resource
          return fallback_label if target.blank?

          "#{target.class.name.demodulize} ##{target.id}"
        end

        def path
          return if target_resource.blank?

          Rails.application.routes.url_helpers.polymorphic_path([namespace, target_resource])
        rescue StandardError
          nil
        end

        def linkable?
          path.present?
        end

        private

        def namespace
          options.fetch(:namespace, :admin)
        end

        def resolve_target_resource
          item = data.presence || resource.reify
          normalize_resource(item)
        rescue StandardError
          nil
        end

        def normalize_resource(item)
          return if item.blank?

          return item.globalized_model if item.respond_to?(:globalized_model) && item.globalized_model.present?

          item
        end

        def fallback_label
          "#{resource.item_type} ##{resource.item_id}"
        end
      end
    end
  end
end

