# frozen_string_literal: true

module YummyGuide
  module Administrate
    module IntegrationTransitionHelper
      # 外部連携の非同期遷移を、製品固有の文言を渡して共通表示する。
      def integration_transition_notice(message:, state:, details: nil)
        warning = state.to_s == 'warning'
        color = (warning || state.to_s == 'failed') ? '#b42318' : '#175cd3'
        background = warning ? '#fef3f2' : '#f8fafc'
        border = warning ? '#fecdca' : color
        icon = if warning
                 content_tag(
                   :span,
                   '⚠',
                   class: 'integration-transition-notice__caution-icon',
                   aria: { hidden: true },
                   style: "color: #{color}; font-size: 20px; line-height: 1;",
                 )
               end

        content_tag(
          :div,
          role: 'status',
          class: "integration-transition-notice integration-transition-notice--#{state}",
          data: { integration_transition_state: state },
          style: "display: flex; gap: 8px; margin: 12px 0; padding: 12px; border: 1px solid #{border}; border-left: 4px solid #{color}; background: #{background}; color: #{color};",
        ) do
          safe_join([
            icon,
            content_tag(:div, safe_join([content_tag(:strong, message), details.present? ? content_tag(:div, details, style: 'margin-top: 4px;') : nil].compact)),
          ].compact)
        end
      end
    end
  end
end
