# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::Fields::VersionItemField do
  before do
    stub_const("SpecVersionItemRecord", Class.new do
      attr_reader :id

      def initialize(id)
        @id = id
      end
    end)
  end

  let(:record) { SpecVersionItemRecord.new(12) }
  let(:resource) { Struct.new(:item_type, :item_id, :reify).new("Widget", 12, nil) }

  def build_field(data = record)
    described_class.new(:item, data, :show, resource: resource, namespace: :admin)
  end

  it "builds a readable label" do
    expect(build_field.label).to eq("SpecVersionItemRecord #12")
  end

  it "uses a fallback label when the target resource is unavailable" do
    expect(build_field(nil).label).to eq("Widget #12")
  end
end
