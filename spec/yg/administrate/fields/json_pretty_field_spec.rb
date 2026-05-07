# frozen_string_literal: true

require "spec_helper"

RSpec.describe Yg::Administrate::Fields::JsonPrettyField do
  def build_field(data)
    described_class.new(:payload, data, :show, resource: Object.new)
  end

  it "pretty prints JSON strings" do
    field = build_field('{"a":1}')

    expect(field.to_s).to include("\"a\": 1")
  end

  it "falls back to the raw string when parsing fails" do
    field = build_field("not-json")

    expect(field.to_s).to eq("not-json")
  end
end

