# frozen_string_literal: true

require "administrate/base_dashboard"

module Yg
  module Administrate
    class ApplicationDashboard < ::Administrate::BaseDashboard
      INDEX_FIXED_COLUMNS_COUNT = 1

      def default_sorting_attribute
        :created_at
      end

      def default_sorting_direction
        :desc
      end

      def self.index_fixed_columns_count
        if const_defined?(:INDEX_FIXED_COLUMNS_COUNT, false)
          const_get(:INDEX_FIXED_COLUMNS_COUNT)
        elsif superclass.respond_to?(:index_fixed_columns_count)
          superclass.index_fixed_columns_count
        else
          0
        end
      end

      def self.collection_sortable_attributes
        if const_defined?(:COLLECTION_SORTABLE_ATTRIBUTES, false)
          const_get(:COLLECTION_SORTABLE_ATTRIBUTES)
        elsif const_defined?(:COLLECTION_ATTRIBUTES, false)
          const_get(:COLLECTION_ATTRIBUTES)
        elsif superclass.respond_to?(:collection_sortable_attributes)
          superclass.collection_sortable_attributes
        else
          []
        end
      end

      def self.collection_attribute_sortable?(attribute_name)
        collection_sortable_attributes.map(&:to_sym).include?(attribute_name.to_sym)
      end
    end
  end
end

