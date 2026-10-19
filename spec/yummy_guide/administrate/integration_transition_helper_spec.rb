# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::IntegrationTransitionHelper do
  let(:view) { ActionView::Base.empty }

  before { view.extend(described_class) }

  # 製品固有の非同期連携状態を共通のアクセシブルな通知として表示すること
  it "renders a status notice with the supplied message and details" do
    html = view.integration_transition_notice(message: "処理中です", state: "processing", details: "対象 Assign: 2件")

    expect(html).to include('role="status"')
    expect(html).to include("処理中です")
    expect(html).to include("対象 Assign: 2件")
  end

  # 紐付け設定が必要な警告は赤色カードとcautionアイコンで強調すること
  it "renders a warning notice as a caution card" do
    html = view.integration_transition_notice(message: "JobOption の紐付け設定が必要", state: "warning")

    expect(html).to include("integration-transition-notice--warning")
    expect(html).to include('data-integration-transition-state="warning"')
    expect(html).to include("integration-transition-notice__caution-icon")
    expect(html).to include("#fef3f2")
  end
end
