# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe YummyGuide::Administrate::FilterControlsHelper do
  subject(:helper_host) do
    Class.new do
      include ActionView::Context
      include ActionView::Helpers::FormHelper
      include ActionView::Helpers::FormOptionsHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::OutputSafetyHelper
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::UrlHelper
      include YummyGuide::Administrate::FilterControlsHelper
    end.new
  end

  def fragment(html)
    Nokogiri::HTML.fragment(html)
  end

  describe "#admin_filter_controls" do
    # dashboard の FILTER_ATTRIBUTES から Filter ボタンとフォーム項目を描画することを確認する
    it "renders controls from dashboard filter attributes" do
      dashboard = Class.new
      dashboard.const_set(
        :FILTER_ATTRIBUTES,
        {
          keyword: YummyGuide::Administrate::Filters::Text.with_options(label: "Keyword"),
          status: YummyGuide::Administrate::Filters::Select.with_options(
            label: "Status",
            collection: [["Open", "open"], ["Closed", "closed"]]
          )
        }.freeze
      )

      html = helper_host.admin_filter_controls(
        dashboard: dashboard,
        path: "/admin/resources",
        search_options: { keyword: "tokyo", status: "closed" }
      )
      document = fragment(html)

      expect(document.at_css("#reserv-filter-options > a.button").text).to eq("Filter")
      expect(document.at_css("form.filter-form")["action"]).to eq("/admin/resources")
      expect(document.at_css('input[name="search_options[keyword]"]')["value"]).to eq("tokyo")
      expect(document.at_css('select[name="search_options[status]"] option[selected]')["value"]).to eq("closed")
    end

    # boolean radio group が未指定・true・falseを横並びで描画し、ラベルと選択状態を反映することを確認する
    it "renders boolean radio group controls with custom labels" do
      dashboard = Class.new
      dashboard.const_set(
        :FILTER_ATTRIBUTES,
        {
          visible: YummyGuide::Administrate::Filters::BooleanRadioGroup.with_options(
            label: "Visible",
            unspecified_label: "-",
            true_label: "Visible",
            false_label: "Hidden"
          )
        }.freeze
      )

      html = helper_host.admin_filter_controls(
        dashboard: dashboard,
        path: "/admin/resources",
        search_options: { visible: "false" }
      )
      document = fragment(html)

      wrapper = document.at_css('input[name="search_options[visible]"]').ancestors("div").first

      expect(document.at_css('input[type="radio"][name="search_options[visible]"][value=""]')).to be_present
      expect(document.at_css('input[type="radio"][name="search_options[visible]"][value="true"]')).to be_present
      expect(document.at_css('input[type="radio"][name="search_options[visible]"][value="false"]')).to be_present
      expect(document.at_css('input[type="radio"][name="search_options[visible]"][value="false"]')["checked"]).to eq("checked")
      expect(wrapper["style"]).to include("display: flex")
      expect(document.text).to include("-", "Visible", "Hidden")
    end

    # dashboard に定義した FILTER_PATH をフィルター送信先として利用できることを確認する
    it "uses dashboard filter path when no explicit path is passed" do
      dashboard = Class.new
      dashboard.const_set(
        :FILTER_ATTRIBUTES,
        {
          keyword: YummyGuide::Administrate::Filters::Text.with_options(label: "Keyword")
        }.freeze
      )
      dashboard.const_set(:FILTER_PATH, ->(view, _locals) { view.filter_path })

      helper_host.define_singleton_method(:filter_path) { "/admin/dashboard-filters" }

      html = helper_host.admin_filter_controls(dashboard: dashboard)
      document = fragment(html)

      expect(document.at_css("form.filter-form")["action"]).to eq("/admin/dashboard-filters")
    end

    # dashboard にフィルター定義が存在しない場合は Filter ボタンを描画しないことを確認する
    it "does not render controls when dashboard has no filter attributes" do
      expect(helper_host.admin_filter_controls(dashboard: Class.new, path: "/admin/resources")).to be_nil
    end
  end
end
