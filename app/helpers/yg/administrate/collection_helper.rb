# frozen_string_literal: true

module Yg
  module Administrate
    module CollectionHelper
      def yg_administrate_collection_table_fixed_columns_count(page:, collection_presenter:)
        return 0 unless page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)

        dashboard = page.instance_variable_get(:@dashboard)
        return 0 unless dashboard&.class&.respond_to?(:index_fixed_columns_count)

        fixed_columns_count = dashboard.class.index_fixed_columns_count.to_i
        fixed_columns_count = 0 if fixed_columns_count.negative?

        attribute_count = collection_presenter.attribute_types.size
        [fixed_columns_count, attribute_count].min
      rescue NoMethodError
        0
      end

      def yg_administrate_collection_detail_path(resource, namespace:)
        return if resource.blank?
        return if respond_to?(:accessible_action?) && !accessible_action?(resource, :show)

        polymorphic_path([namespace, resource])
      rescue StandardError
        nil
      end

      def yg_administrate_collection_attribute_path(attribute:, resource:, namespace:)
        if yg_administrate_collection_reference_link?(attribute)
          yg_administrate_collection_detail_path(attribute.data, namespace: namespace)
        elsif yg_administrate_collection_text_link?(attribute)
          yg_administrate_collection_detail_path(resource, namespace: namespace)
        end
      end

      def yg_administrate_collection_reference_link?(attribute)
        attribute.is_a?(::Administrate::Field::BelongsTo) && attribute.data.present?
      end

      def yg_administrate_collection_text_link?(attribute)
        attribute.respond_to?(:name) && attribute.name.to_s == "id"
      end

      def yg_administrate_collection_wrap(content, href:)
        return content if href.blank?

        link_to(href, class: "action-show") { content }
      end

      def yg_administrate_collection_actions_partial(partial_name)
        if controller.respond_to?(:controller_path)
          controller_partial = "#{controller.controller_path}/#{partial_name}"
          return controller_partial if lookup_context.exists?(controller_partial, [], true)
        end

        "administrate/application/#{partial_name}"
      end
    end
  end
end
