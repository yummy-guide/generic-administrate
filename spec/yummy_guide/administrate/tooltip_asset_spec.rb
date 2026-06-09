# frozen_string_literal: true

RSpec.describe "tooltip assets" do
  let(:javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/tooltips.js", __dir__))
  end

  let(:stylesheet_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/_tooltips.scss", __dir__))
  end

  let(:engine_source) do
    File.read(File.expand_path("../../../lib/yummy_guide/administrate/engine.rb", __dir__))
  end

  # PC では hover と keyboard focus で tooltip を表示するイベント契約を持つことを静的に確認する
  it "supports desktop hover and focus interactions" do
    expect(javascript_source).to include('document.addEventListener("mouseover"')
    expect(javascript_source).to include('document.addEventListener("mouseout"')
    expect(javascript_source).to include('document.addEventListener("focusin"')
    expect(javascript_source).to include('document.addEventListener("focusout"')
    expect(javascript_source).to include("showTooltip(trigger)")
  end

  # モバイルではクリックで tooltip 表示をトグルする契約を持つことを静的に確認する
  it "supports mobile click toggling" do
    expect(javascript_source).to include('MOBILE_MEDIA_QUERY = "(max-width: 767px)"')
    expect(javascript_source).to include("window.matchMedia")
    expect(javascript_source).to include('document.addEventListener("click"')
    expect(javascript_source).to include("toggleTooltip(trigger)")
    expect(javascript_source).to include("event.stopPropagation()")
  end

  # Esc / 外側クリック / resize で表示中 tooltip を閉じられることを静的に確認する
  it "closes the active tooltip from common dismissal events" do
    expect(javascript_source).to include('event.key !== "Escape"')
    expect(javascript_source).to include("if (activeTrigger && isMobile())")
    expect(javascript_source).to include('window.addEventListener("resize"')
    expect(javascript_source).to include("hideTooltip()")
  end

  # block本文用のtemplateがある場合はHTML本文としてtooltipへ描画することを静的に確認する
  it "renders template content for block tooltip bodies" do
    expect(javascript_source).to include('getAttribute("data-admin-tooltip-content-id")')
    expect(javascript_source).to include("template.innerHTML")
    expect(javascript_source).to include("tooltipElement.innerHTML = content.html")
    expect(javascript_source).to include("tooltipElement.textContent = content.text")
  end

  # tooltip の吹き出しと表示状態に必要な CSS class が定義されることを静的に確認する
  it "defines tooltip trigger and bubble styles" do
    expect(stylesheet_source).to include(".admin-tooltip-trigger")
    expect(stylesheet_source).to include(".admin-tooltip")
    expect(stylesheet_source).to include(".admin-tooltip--visible")
    expect(stylesheet_source).to include('data-admin-tooltip-placement="top"')
    expect(stylesheet_source).to include("max-width: calc(100vw - 24px)")
  end

  # tooltip の JS asset が engine の precompile 対象に入ることを確認する
  it "precompiles the tooltip javascript asset" do
    expect(engine_source).to include("yummy_guide_administrate/tooltips.js")
  end
end
