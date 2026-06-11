# frozen_string_literal: true

require "administrate/base_dashboard"

module YummyGuide
  module Administrate
    class ApplicationDashboard < ::Administrate::BaseDashboard
      INDEX_FIXED_COLUMNS_COUNT = 1
      INDEX_FIXED_COLUMN_WIDTHS = {}.freeze

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

      def self.index_mobile_fixed_columns_count
        if const_defined?(:INDEX_MOBILE_FIXED_COLUMNS_COUNT, false)
          const_get(:INDEX_MOBILE_FIXED_COLUMNS_COUNT)
        elsif const_defined?(:INDEX_FIXED_COLUMNS_COUNT, false)
          [index_fixed_columns_count.to_i, 1].min
        elsif superclass.respond_to?(:index_mobile_fixed_columns_count)
          superclass.index_mobile_fixed_columns_count
        else
          [index_fixed_columns_count.to_i, 1].min
        end
      end

      def self.index_fixed_column_widths
        if const_defined?(:INDEX_FIXED_COLUMN_WIDTHS, false)
          const_get(:INDEX_FIXED_COLUMN_WIDTHS)
        elsif superclass.respond_to?(:index_fixed_column_widths)
          superclass.index_fixed_column_widths
        else
          {}
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
