# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::FilterFormHelper do
  subject(:helper_host) do
    Class.new do
      include YummyGuide::Administrate::FilterFormHelper
    end.new
  end

  before do
    Time.zone = "Tokyo"
  end

  it "normalizes current values to string keys" do
    values = ActionController::Parameters.new(start_date: "2026-05-07")

    expect(helper_host.yummy_guide_administrate_filter_current_values(values)).to eq("start_date" => "2026-05-07")
  end

  it "builds end-of-day defaults for date-only inputs" do
    parts = helper_host.yummy_guide_administrate_datetime_filter_parts("2026-05-07", end_of_day: true)

    expect(parts).to eq(date: "2026-05-07", hour: "23", minute: "59")
  end

  it "combines parsed datetime parts back into a single value" do
    combined = helper_host.yummy_guide_administrate_datetime_filter_combined_value(date: "2026-05-07", hour: "08", minute: "00")

    expect(combined).to eq("2026-05-07T08:00")
  end

  it "maps checkbox group objects through label and value methods" do
    option = Struct.new(:id, :name).new(10, "Japanese")

    expect(helper_host.yummy_guide_administrate_checkbox_group_options([option], label_method: :name, value_method: :id)).to eq([["Japanese", 10]])
  end
end

