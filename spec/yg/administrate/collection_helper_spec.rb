# frozen_string_literal: true

require "spec_helper"

RSpec.describe Yg::Administrate::CollectionHelper do
  subject(:helper_host) do
    Class.new do
      include Yg::Administrate::CollectionHelper
    end.new
  end

  it "caps the fixed column count by the number of visible attributes" do
    dashboard_class = Class.new do
      def self.index_fixed_columns_count
        4
      end
    end

    page = Object.new
    page.instance_variable_set(:@dashboard, dashboard_class.new)
    collection_presenter = Struct.new(:attribute_types).new({ id: :integer, name: :string })

    expect(helper_host.yg_administrate_collection_table_fixed_columns_count(page: page, collection_presenter: collection_presenter)).to eq(2)
  end
end
