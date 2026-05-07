# frozen_string_literal: true

require "spec_helper"

RSpec.describe Yg::Administrate::DatetimeFilterParameters do
  subject(:host) do
    Class.new do
      include Yg::Administrate::DatetimeFilterParameters

      def normalize(filters, keys:)
        normalize_datetime_filter_params(filters, keys: keys)
      end
    end.new
  end

  it "combines date and time parts into a datetime-local string" do
    filters = ActionController::Parameters.new(
      start_date_date: "2026-05-07",
      start_date_hour: "09",
      start_date_minute: "30"
    )

    normalized = host.normalize(filters, keys: [:start_date])

    expect(normalized[:start_date]).to eq("2026-05-07T09:30")
    expect(normalized).not_to have_key(:start_date_date)
  end

  it "returns just the date when time parts are blank" do
    filters = ActionController::Parameters.new(
      end_date_date: "2026-05-07",
      end_date_hour: "",
      end_date_minute: ""
    )

    normalized = host.normalize(filters, keys: [:end_date])

    expect(normalized[:end_date]).to eq("2026-05-07")
  end

  it "sets nil when the date is blank" do
    filters = ActionController::Parameters.new(
      start_date_date: "",
      start_date_hour: "09",
      start_date_minute: "30"
    )

    normalized = host.normalize(filters, keys: [:start_date])

    expect(normalized[:start_date]).to be_nil
  end
end
