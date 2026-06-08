# frozen_string_literal: true

module YummyGuide
  module Administrate
    module FilterControlsHelper
      def admin_filter_controls(
        dashboard: nil,
        page: nil,
        path: nil,
        clear_path: nil,
        search_options: {},
        form: :search_options,
        method: :get,
        hidden_fields: {},
        root_hidden_fields: {},
        filter_locals: {},
        extra_actions: [],
        button_label: "Filter",
        title: "Filter Options",
        submit_label: "Filter",
        close_label: "Close",
        modal_mount: :inline,
        modal_content_for: :admin_filter_modals
      )
        dashboard ||= admin_filter_dashboard_from_page(page)
        scope = form.to_s
        current_values = admin_filter_current_values(search_options)
        base_locals = filter_locals.merge(
          dashboard: dashboard,
          page: page,
          search_options: search_options,
          current_values: current_values,
          form_scope: scope
        )
        fields = admin_filter_visible_fields(dashboard, base_locals)
        return if fields.blank?

        path ||= admin_filter_dashboard_setting(dashboard, :filter_path, :FILTER_PATH, base_locals)
        raise ArgumentError, "admin_filter_controls requires path or dashboard FILTER_PATH" if path.blank?

        clear_path ||= admin_filter_dashboard_setting(dashboard, :filter_clear_path, :FILTER_CLEAR_PATH, base_locals) || path
        locals = filter_locals.merge(
          dashboard: dashboard,
          page: page,
          path: path,
          clear_path: clear_path,
          search_options: search_options,
          current_values: current_values,
          form_scope: scope
        )

        form_markup = admin_filter_form(
          fields: fields,
          scope: scope,
          path: path,
          clear_path: clear_path,
          method: method,
          current_values: current_values,
          hidden_fields: hidden_fields,
          root_hidden_fields: root_hidden_fields,
          locals: locals,
          extra_actions: extra_actions,
          title: title,
          submit_label: submit_label,
          close_label: close_label
        )

        if admin_filter_body_modal_mount?(modal_mount)
          modal_id = admin_filter_next_modal_id
          content_for(modal_content_for, admin_filter_modal_root(modal_id: modal_id, form_markup: form_markup))

          return admin_filter_button_container(button_label: button_label, modal_id: modal_id)
        end

        safe_join([
          content_tag(:div, "", class: "modal_overlay"),
          admin_filter_button_container(button_label: button_label, form_markup: form_markup)
        ])
      end

      def admin_filter_dashboard_from_page(page)
        return page.dashboard if page.respond_to?(:dashboard)
        return unless page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)

        page.instance_variable_get(:@dashboard)
      end

      def admin_filter_dashboard_setting(dashboard, method_name, constant_name, locals)
        return if dashboard.blank?

        value =
          if dashboard.respond_to?(method_name)
            dashboard.public_send(method_name)
          else
            admin_filter_dashboard_constant(dashboard, constant_name)
          end

        admin_filter_evaluate_value(value, locals)
      end

      def admin_filter_dashboard_constant(dashboard, constant_name)
        target = dashboard.is_a?(Class) ? dashboard : dashboard.class
        target.const_get(constant_name, false) if target.const_defined?(constant_name, false)
      end

      def admin_filter_visible_fields(dashboard, locals)
        return [] if dashboard.blank?

        YummyGuide::Administrate::Filters::Resolver
          .attributes_for(dashboard)
          .values
          .select { |field| field.visible?(self, locals) }
      end

      def admin_filter_form(fields:, scope:, path:, clear_path:, method:, current_values:, hidden_fields:, root_hidden_fields:, locals:, extra_actions:, title:, submit_label:, close_label:)
        form_with(
          url: path,
          scope: scope,
          method: method,
          html: {
            class: "filter-form",
            data: {
              yummy_guide_administrate_filter_form: true,
              admin_filter_form: true
            }
          }
        ) do |f|
          safe_join([
            admin_filter_hidden_fields(scope, hidden_fields, root_hidden_fields),
            admin_filter_form_header(title: title, close_label: close_label),
            content_tag(:div, class: "filter-form__body") do
              content_tag(:table, class: "filter_table") do
                safe_join(fields.map { |field| field.row(self, f, scope, current_values, locals) })
              end
            end,
            content_tag(:div, class: "filter-form__actions") do
              safe_join([
                link_to("Clear", clear_path, class: "button button--outline-primary"),
                Array(extra_actions),
                f.submit(submit_label, class: "submit_filter")
              ].flatten)
            end
          ])
        end
      end

      def admin_filter_button_container(button_label:, form_markup: nil, modal_id: nil)
        data = { admin_filter_controls: true }
        data[:admin_filter_modal_id] = modal_id if modal_id

        content_tag(:div, id: "reserv-filter-options", data: data) do
          safe_join([
            link_to(button_label, "javascript:void(0)", class: "button"),
            form_markup
          ].compact)
        end
      end

      def admin_filter_modal_root(modal_id:, form_markup:)
        content_tag(:div, id: modal_id, class: "admin-filter-modal-root", data: { admin_filter_modal_root: true }) do
          safe_join([
            content_tag(:div, "", class: "modal_overlay"),
            form_markup
          ])
        end
      end

      def admin_filter_body_modal_mount?(modal_mount)
        modal_mount.to_s == "body"
      end

      def admin_filter_next_modal_id
        @admin_filter_controls_modal_index ||= 0
        @admin_filter_controls_modal_index += 1
        "admin-filter-modal-#{@admin_filter_controls_modal_index}"
      end

      def admin_filter_form_header(title:, close_label:)
        content_tag(:div, class: "filter-form__header") do
          safe_join([
            content_tag(:h2, title, class: "filter-form__title"),
            button_tag(
              "x",
              type: "button",
              class: "filter-form__close",
              data: { behavior: "filter-form-close" },
              aria: { label: close_label },
              title: close_label
            )
          ])
        end
      end

      def admin_filter_hidden_fields(scope, hidden_fields, root_hidden_fields)
        root_tags = admin_filter_evaluated_hash(root_hidden_fields).map do |key, value|
          hidden_field_tag(key, value)
        end

        scoped_tags = admin_filter_evaluated_hash(hidden_fields).map do |key, value|
          hidden_field_tag("#{scope}[#{key}]", value)
        end

        safe_join(root_tags + scoped_tags)
      end

      def admin_filter_evaluated_hash(values)
        values = admin_filter_evaluate_value(values, {})
        (values || {}).to_h
      end

      def admin_filter_evaluate_value(value, locals)
        return value unless value.respond_to?(:call)

        case value.arity
        when 0
          value.call
        when 1
          value.call(self)
        else
          value.call(self, locals)
        end
      end

      def admin_filter_current_values(raw_values)
        values =
          if raw_values.respond_to?(:to_unsafe_h)
            raw_values.to_unsafe_h
          elsif raw_values.respond_to?(:to_h)
            raw_values.to_h
          else
            raw_values || {}
          end

        values.deep_stringify_keys
      end
    end
  end
end
