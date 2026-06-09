# frozen_string_literal: true

require "spec_helper"
require "nokogiri"

RSpec.describe YummyGuide::Administrate::TooltipHelper do
  subject(:helper_host) do
    Class.new do
      include ActionView::Context
      include ActionView::Helpers::CaptureHelper
      include ActionView::Helpers::OutputSafetyHelper
      include ActionView::Helpers::TagHelper
      include YummyGuide::Administrate::TooltipHelper
    end.new
  end

  def fragment(html)
    Nokogiri::HTML.fragment(html)
  end

  describe "#admin_tooltip" do
    # tooltip 表示用の button と JS が参照する data 属性を描画することを確認する
    it "renders an icon button tooltip trigger" do
      document = fragment(helper_host.admin_tooltip("公開ページに表示されます。"))
      button = document.at_css("button.admin-tooltip-trigger")

      expect(button["type"]).to eq("button")
      expect(button["data-admin-tooltip-trigger"]).to eq("true")
      expect(button["data-admin-tooltip-text"]).to eq("公開ページに表示されます。")
      expect(button["aria-label"]).to eq("説明を表示")
      expect(button["aria-expanded"]).to eq("false")
      expect(button.at_css(".admin-tooltip-trigger__icon").text).to eq("?")
      expect(button.at_css(".admin-tooltip-trigger__icon")["aria-hidden"]).to eq("true")
    end

    # tooltip 本文に HTML が含まれても子要素として展開されず data 属性へ escape されることを確認する
    it "escapes tooltip text instead of rendering it as HTML" do
      html = helper_host.admin_tooltip(%(<strong onclick="alert(1)">説明</strong>))
      document = fragment(html)
      button = document.at_css("button.admin-tooltip-trigger")

      expect(document.at_css("strong")).to be_nil
      expect(button["data-admin-tooltip-text"]).to eq(%(<strong onclick="alert(1)">説明</strong>))
      expect(html).to include("&lt;strong")
    end

    # block を渡した場合は説明本文として template に描画し、text 引数より優先されることを確認する
    it "renders block content as the tooltip body before text content" do
      document = fragment(
        helper_host.admin_tooltip("Fallback text") do
          helper_host.safe_join([
            helper_host.content_tag(:span, "Add - 調整レコードを追加表示するようにします。"),
            helper_host.tag.br,
            helper_host.content_tag(:span, "Only - 調整レコードのみを表示します。")
          ])
        end
      )
      button = document.at_css("button.admin-tooltip-trigger")
      template = document.at_css("template")

      expect(button["data-admin-tooltip-text"]).to be_nil
      expect(button["data-admin-tooltip-content-id"]).to eq(template["id"])
      expect(template.text).to include("Add - 調整レコードを追加表示するようにします。")
      expect(template.text).to include("Only - 調整レコードのみを表示します。")
      expect(template.at_css("br")).to be_present
      expect(template.text).not_to include("Fallback text")
    end

    # 呼び出し側が指定した class / data / aria label を維持しつつ tooltip 用 data を優先することを確認する
    it "merges custom attributes without allowing tooltip data overrides" do
      document = fragment(
        helper_host.admin_tooltip(
          "ステータスの補足です。",
          aria_label: "補足を開く",
          class: "status-tooltip",
          data: {
            tracking_key: "status",
            admin_tooltip_text: "上書きされない説明"
          }
        )
      )
      button = document.at_css("button.admin-tooltip-trigger")

      expect(button["class"]).to include("admin-tooltip-trigger", "status-tooltip")
      expect(button["aria-label"]).to eq("補足を開く")
      expect(button["data-tracking-key"]).to eq("status")
      expect(button["data-admin-tooltip-trigger"]).to eq("true")
      expect(button["data-admin-tooltip-text"]).to eq("ステータスの補足です。")
    end

    # 空の説明文では空ボタンを描画しないことを確認する
    it "does not render a trigger for blank text" do
      expect(helper_host.admin_tooltip("")).to be_nil
    end
  end
end
