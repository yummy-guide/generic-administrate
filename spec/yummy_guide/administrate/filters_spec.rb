# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe YummyGuide::Administrate::Filters do
  describe YummyGuide::Administrate::Filters::Resolver do
    # dashboard に定義した Field クラス型フィルターへ属性名が付与されることを確認する
    it "normalizes dashboard filter attributes with field names" do
      dashboard = Class.new
      dashboard.const_set(
        :FILTER_ATTRIBUTES,
        {
          keyword: YummyGuide::Administrate::Filters::Text.with_options(label: "Keyword")
        }.freeze
      )

      fields = described_class.attributes_for(dashboard)

      expect(fields[:keyword]).to be_a(YummyGuide::Administrate::Filters::Text)
      expect(fields[:keyword].name).to eq(:keyword)
    end
  end

  describe "#visible?" do
    # view context に依存する条件でフィルター表示を切り替えられることを確認する
    it "evaluates visibility conditions with the view context" do
      view_context = double("view_context", owner?: true)
      field = YummyGuide::Administrate::Filters::Text
        .with_options(if: ->(view, _locals) { !view.owner? })
        .with_name(:owner_name)

      expect(field.visible?(view_context, {})).to be(false)
    end
  end

  describe YummyGuide::Administrate::Filters::CheckboxGroup do
    # current_values に値がない場合は default 配列を選択状態として利用することを確認する
    it "uses default values when current values do not include the field" do
      view_context = ActionController::Base.helpers
      form = double("form")
      field = described_class.with_options(
        collection: [["Open", "open"], ["Closed", "closed"]],
        default: ["closed"]
      ).with_name(:statuses)

      html = field.send(:input_cell, view_context, form, :search_options, {}, {})
      document = Nokogiri::HTML.fragment(html)

      expect(document.at_css('input[value="closed"]')["checked"]).to eq("checked")
      expect(document.at_css('input[value="open"]')["checked"]).to be_nil
    end
  end
end
