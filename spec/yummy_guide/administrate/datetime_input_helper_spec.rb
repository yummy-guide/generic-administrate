# frozen_string_literal: true

require "spec_helper"
require "active_support/testing/time_helpers"
require "nokogiri"

RSpec.describe YummyGuide::Administrate::DatetimeInputHelper do
  include ActiveSupport::Testing::TimeHelpers

  subject(:helper_host) do
    Class.new do
      include ActionView::Context
      include ActionView::Helpers::CaptureHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::OutputSafetyHelper
      include ActionView::Helpers::TagHelper
      include YummyGuide::Administrate::DatetimeInputHelper
    end.new
  end

  before do
    Time.zone = "Tokyo"
  end

  after do
    travel_back
  end

  describe "#admin_datetime_field_tag" do
    # hidden の送信値と visible な date + time 入力 UI を描画することを確認する
    it "renders a combined datetime target with visible date and time inputs" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_datetime_field_tag("coupon[expiration_date]", "2026-04-30T09:05"))

      expect(fragment.at_css('[data-admin-datetime-input="true"]')["data-admin-datetime-mode"]).to eq("combined")
      expect(fragment.at_css('input[name="coupon[expiration_date]"]')["value"]).to eq("2026-04-30T09:05")
      expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["type"]).to eq("date")
      expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["value"]).to eq("2026-04-30")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("09:05")
      expect(fragment.at_css('[data-admin-datetime-role="error"]').text.strip).to eq("")
    end

    # 新規フォーム向けの指定時は未入力でも現在日時で初期表示されることを確認する
    it "defaults blank values to the current datetime when requested" do
      travel_to(Time.zone.local(2026, 4, 30, 17, 0, 45)) do
        fragment = Nokogiri::HTML.fragment(
          helper_host.admin_datetime_field_tag("coupon[expiration_date]", nil, default_current_time: true)
        )

        expect(fragment.at_css('input[name="coupon[expiration_date]"]')["value"]).to eq("2026-04-30T17:00")
        expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["value"]).to eq("2026-04-30")
        expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("17:00")
      end
    end
  end

  describe "#admin_split_datetime_field_tag" do
    # split 出力 helper が既存 controller 契約に合わせた hidden target と date + time 入力 UI を描画することを確認する
    it "renders split hidden targets and visible date and time inputs for the current datetime" do
      fragment = Nokogiri::HTML.fragment(
        helper_host.admin_split_datetime_field_tag(
          date_name: "coupon[expiration_date_date]",
          hour_name: "coupon[expiration_date_hour]",
          minute_name: "coupon[expiration_date_minute]",
          value: Time.zone.local(2026, 4, 30, 9, 5, 0)
        )
      )

      expect(fragment.at_css('input[name="coupon[expiration_date_date]"]')["value"]).to eq("2026-04-30")
      expect(fragment.at_css('input[name="coupon[expiration_date_hour]"]')["value"]).to eq("09")
      expect(fragment.at_css('input[name="coupon[expiration_date_minute]"]')["value"]).to eq("05")
      expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["value"]).to eq("2026-04-30")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("09:05")
    end
  end

  describe "#admin_date_and_time_field_tag" do
    # date + time 文字列 helper が既存 hidden 契約を維持しつつ date + time 入力 UI を描画することを確認する
    it "renders split hidden targets for date and time inputs" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_date_and_time_field_tag(
        date_name: "reservation_task[due_date_on]",
        time_name: "reservation_task[due_time]",
        value: "2026-05-01 10:15"
      ))

      expect(fragment.at_css('[data-admin-datetime-input="true"]')["data-admin-datetime-mode"]).to eq("date_and_time")
      expect(fragment.at_css('input[name="reservation_task[due_date_on]"]')["value"]).to eq("2026-05-01")
      expect(fragment.at_css('input[name="reservation_task[due_time]"]')["value"]).to eq("10:15")
      expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["value"]).to eq("2026-05-01")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("10:15")
    end

    # 日付が完成していて時刻が1-2桁だけのときは、time の raw 値を維持して hidden target を空で再描画することを確認する
    it "preserves incomplete one or two digit times for date and time inputs" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_date_and_time_field_tag(
        date_name: "reservation_task[due_date_on]",
        time_name: "reservation_task[due_time]",
        value: "2026-05-01 9"
      ))

      expect(fragment.at_css('input[name="reservation_task[due_date_on]"]')["value"]).to eq("2026-05-01")
      expect(fragment.at_css('input[name="reservation_task[due_time]"]')["value"]).to eq("")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("9")
    end
  end

  describe "#admin_time_field_tag" do
    # 時刻のみ helper が hidden target と単一 time 入力 UI を描画することを確認する
    it "renders a time-only input with hidden normalized value" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_time_field_tag("option[valid_from_time]", "9:5"))

      expect(fragment.at_css('[data-admin-datetime-input="true"]')["data-admin-datetime-mode"]).to eq("time_only")
      expect(fragment.at_css('input[name="option[valid_from_time]"]')["value"]).to eq("09:05")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("09:05")
    end

    # 1-2桁の未完成時刻は単一 time 入力にそのまま残し、hidden target を空にして再描画することを確認する
    it "preserves incomplete one or two digit times without coercing them to minutes" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_time_field_tag("option[valid_from_time]", "9"))

      expect(fragment.at_css('input[name="option[valid_from_time]"]')["value"]).to eq("")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("9")
    end
  end

  describe "invalid datetime rendering" do
    # 不正な日時文字列でも visible time 入力に raw 値を残し、hidden 値は空で invalid 状態になることを確認する
    it "preserves raw numeric segments and marks the component invalid" do
      fragment = Nokogiri::HTML.fragment(helper_host.admin_datetime_field_tag("coupon[expiration_date]", "2026/02/30 18:61"))

      expect(fragment.at_css('[data-admin-datetime-input="true"]')["data-admin-datetime-valid"]).to eq("false")
      expect(fragment.at_css('input[name="coupon[expiration_date]"]')["value"]).to eq("")
      expect(fragment.at_css('[data-admin-datetime-role="date-input"]')["value"]).to eq("")
      expect(fragment.at_css('[data-admin-datetime-role="time-input"]')["value"]).to eq("18:61")
      expect(fragment.at_css('[data-admin-datetime-role="error"]').text.strip).to eq("日付を正しく入力してください。")
    end
  end
end
