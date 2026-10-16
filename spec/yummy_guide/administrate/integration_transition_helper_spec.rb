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
end
