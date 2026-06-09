# frozen_string_literal: true

module YummyGuide
  module Administrate
    module TooltipHelper
      def admin_tooltip(text = nil, aria_label: "説明を表示", class: nil, data: {}, &block)
        return if text.blank? && !block_given?

        custom_class = binding.local_variable_get(:class)
        content_id = admin_tooltip_content_id if block_given?

        safe_join([
          content_tag(
            :button,
            type: "button",
            class: token_list("admin-tooltip-trigger", custom_class),
            data: admin_tooltip_data_attributes(data, text: text.to_s, content_id: content_id),
            aria: {
              label: aria_label,
              expanded: "false"
            }
          ) do
            tag.span("?", class: "admin-tooltip-trigger__icon", aria: { hidden: true })
          end,
          (content_tag(:template, capture(&block), id: content_id) if content_id)
        ].compact)
      end

      private

      def admin_tooltip_content_id
        @admin_tooltip_index ||= 0
        @admin_tooltip_index += 1
        "admin-tooltip-content-#{@admin_tooltip_index}"
      end

      def admin_tooltip_data_attributes(data, text:, content_id:)
        attributes = (data || {}).to_h.deep_dup
        attributes.delete(:admin_tooltip_trigger)
        attributes.delete("admin_tooltip_trigger")
        attributes.delete(:admin_tooltip_text)
        attributes.delete("admin_tooltip_text")
        attributes.delete(:admin_tooltip_content_id)
        attributes.delete("admin_tooltip_content_id")

        attributes[:admin_tooltip_trigger] = true
        if content_id
          attributes[:admin_tooltip_content_id] = content_id
        else
          attributes[:admin_tooltip_text] = text
        end

        attributes
      end
    end
  end
end
