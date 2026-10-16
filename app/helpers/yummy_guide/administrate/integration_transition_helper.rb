# frozen_string_literal: true

module YummyGuide
  module Administrate
    module IntegrationTransitionHelper
      # 外部連携の非同期遷移を、製品固有の文言を渡して共通表示する。
      def integration_transition_notice(message:, state:, details: nil)
        color = state.to_s == 'failed' ? '#b42318' : '#175cd3'
        content_tag(:div, role: 'status', style: "margin: 12px 0; padding: 12px; border-left: 4px solid #{color}; background: #f8fafc;") do
          safe_join([content_tag(:strong, message), details.present? ? content_tag(:div, details, style: 'margin-top: 4px;') : nil].compact)
        end
      end
    end
  end
end
