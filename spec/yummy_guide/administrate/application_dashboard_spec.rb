# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::ApplicationDashboard do
  describe ".index_fixed_columns_count" do
    it "returns the subclass constant when defined" do
      subclass = Class.new(described_class)
      subclass.const_set(:INDEX_FIXED_COLUMNS_COUNT, 3)

      expect(subclass.index_fixed_columns_count).to eq(3)
    end

    it "falls back to the superclass value" do
      subclass = Class.new(described_class)

      expect(subclass.index_fixed_columns_count).to eq(1)
    end
  end

  describe ".index_mobile_fixed_columns_count" do
    it "uses the subclass mobile constant when defined" do
      subclass = Class.new(described_class)
      subclass.const_set(:INDEX_FIXED_COLUMNS_COUNT, 5)
      subclass.const_set(:INDEX_MOBILE_FIXED_COLUMNS_COUNT, 2)

      expect(subclass.index_mobile_fixed_columns_count).to eq(2)
    end

    it "caps a subclass desktop fixed column count to one by default" do
      subclass = Class.new(described_class)
      subclass.const_set(:INDEX_FIXED_COLUMNS_COUNT, 5)

      expect(subclass.index_mobile_fixed_columns_count).to eq(1)
    end

    it "keeps zero fixed columns on mobile when desktop fixed columns are zero" do
      subclass = Class.new(described_class)
      subclass.const_set(:INDEX_FIXED_COLUMNS_COUNT, 0)

      expect(subclass.index_mobile_fixed_columns_count).to eq(0)
    end
  end

  describe ".collection_attribute_sortable?" do
    it "uses collection attributes when explicit sortable attributes are absent" do
      subclass = Class.new(described_class)
      subclass.const_set(:COLLECTION_ATTRIBUTES, %i[id created_at])

      expect(subclass.collection_attribute_sortable?(:created_at)).to be(true)
      expect(subclass.collection_attribute_sortable?(:name)).to be(false)
    end

    it "prefers explicit sortable attributes when present" do
      subclass = Class.new(described_class)
      subclass.const_set(:COLLECTION_ATTRIBUTES, %i[id created_at])
      subclass.const_set(:COLLECTION_SORTABLE_ATTRIBUTES, %i[name])

      expect(subclass.collection_attribute_sortable?(:name)).to be(true)
      expect(subclass.collection_attribute_sortable?(:created_at)).to be(false)
    end
  end
end
