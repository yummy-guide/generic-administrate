# frozen_string_literal: true

require "spec_helper"

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
end
