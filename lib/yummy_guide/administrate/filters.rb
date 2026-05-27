# frozen_string_literal: true

module YummyGuide
  module Administrate
    module Filters
      class Base
        attr_reader :name, :options

        def self.with_options(options = {})
          new(options)
        end

        def initialize(options = {})
          @options = options.symbolize_keys
        end

        def with_name(name)
          copy = dup
          copy.instance_variable_set(:@name, name.to_sym)
          copy
        end

        def visible?(view_context, locals)
          condition = options.fetch(:if, true)
          evaluate_option(condition, view_context, locals) != false
        end

        def row(view_context, form, scope, current_values, locals)
          view_context.content_tag(:tr) do
            view_context.safe_join([
              label_cell(view_context, form, locals),
              input_cell(view_context, form, scope, current_values, locals),
              clear_cell(view_context)
            ])
          end
        end

        def label_text(view_context, locals)
          evaluated_label = evaluate_option(options[:label], view_context, locals)
          return evaluated_label if evaluated_label.present?

          name.to_s.humanize
        end

        protected

        def label_cell(view_context, form, locals)
          view_context.content_tag(:td, form.label(name, label_text(view_context, locals)))
        end

        def input_cell(view_context, form, _scope, current_values, locals)
          view_context.content_tag(:td, input(view_context, form, current_values, locals))
        end

        def clear_cell(view_context)
          return view_context.filter_field_clear_cell if view_context.respond_to?(:filter_field_clear_cell)

          view_context.content_tag(:td, "", class: "filter-table__clear")
        end

        def current_value(current_values)
          value = current_values[name.to_s]
          value.presence || options[:default]
        end

        def html_options(view_context, locals)
          options.slice(:placeholder, :inputmode, :pattern, :class, :id, :autocomplete).transform_values do |value|
            evaluate_option(value, view_context, locals)
          end.compact
        end

        def evaluate_option(value, view_context, locals)
          return value unless value.respond_to?(:call)

          case value.arity
          when 0
            value.call
          when 1
            value.call(view_context)
          else
            value.call(view_context, locals)
          end
        end

        def normalize_options(view_context, locals)
          raw_options = evaluate_option(options[:collection] || options[:options], view_context, locals)

          Array(raw_options).map do |option|
            if option.is_a?(Array)
              option
            else
              [option, option]
            end
          end
        end

        def input(_view_context, _form, _current_values, _locals)
          raise NotImplementedError
        end
      end

      class Text < Base
        private

        def input(view_context, form, current_values, locals)
          form.text_field(name, html_options(view_context, locals).merge(value: current_value(current_values)))
        end
      end

      class Select < Base
        private

        def input(view_context, form, current_values, locals)
          selected = current_value(current_values)
          form.select(
            name,
            view_context.options_for_select(normalize_options(view_context, locals), selected),
            evaluate_option(options[:select_options] || {}, view_context, locals),
            html_options(view_context, locals)
          )
        end
      end

      class Checkbox < Base
        private

        def input(view_context, form, current_values, locals)
          checked_value = options.fetch(:checked_value, "true")
          unchecked_value = options.fetch(:unchecked_value, "false")
          checked = ActiveModel::Type::Boolean.new.cast(current_value(current_values))
          form.check_box(name, html_options(view_context, locals).merge(checked: checked), checked_value, unchecked_value)
        end
      end

      class RadioGroup < Base
        protected

        def input_cell(view_context, _form, scope, current_values, locals)
          selected = current_value(current_values).to_s
          controls = normalize_options(view_context, locals).map do |label, value|
            value_string = value.to_s
            id = "#{scope}_#{name}_#{value_string.parameterize(separator: "_")}"
            view_context.content_tag(:label, style: "display: flex; align-items: center; gap: 6px;") do
              view_context.safe_join([
                view_context.radio_button_tag("#{scope}[#{name}]", value, selected == value_string, id: id),
                view_context.content_tag(:span, label)
              ])
            end
          end

          view_context.content_tag(:td, view_context.safe_join(controls))
        end
      end

      class BooleanRadioGroup < Base
        protected

        def input_cell(view_context, _form, scope, current_values, locals)
          selected = current_value(current_values).to_s
          controls = boolean_options(view_context, locals).map do |label, value|
            value_string = value.to_s
            id = "#{scope}_#{name}_#{value_string.presence || "unspecified"}".parameterize(separator: "_")

            view_context.content_tag(:label, style: "display: inline-flex; align-items: center; gap: 6px;") do
              view_context.safe_join([
                view_context.radio_button_tag("#{scope}[#{name}]", value, selected == value_string, id: id),
                view_context.content_tag(:span, label)
              ])
            end
          end

          view_context.content_tag(:td) do
            view_context.content_tag(:div, view_context.safe_join(controls), style: "display: flex; align-items: center; gap: 12px; flex-wrap: wrap;")
          end
        end

        private

        def boolean_options(view_context, locals)
          [
            [evaluate_option(options.fetch(:unspecified_label, "Unspecified"), view_context, locals), ""],
            [evaluate_option(options.fetch(:true_label, "true"), view_context, locals), "true"],
            [evaluate_option(options.fetch(:false_label, "false"), view_context, locals), "false"]
          ]
        end
      end

      class CheckboxGroup < Base
        protected

        def input_cell(view_context, _form, scope, current_values, locals)
          selected_values = Array(current_values[name.to_s]).map(&:to_s).reject(&:blank?)
          group_name = (options[:group] || name).to_s.dasherize
          controls = normalize_options(view_context, locals).map do |label, value|
            value_string = value.to_s
            id = "#{scope}_#{name}_#{value_string.parameterize(separator: "_")}"
            view_context.content_tag(:label, style: "display: flex; align-items: center; gap: 6px;") do
              view_context.safe_join([
                view_context.check_box_tag(
                  "#{scope}[#{name}][]",
                  value,
                  selected_values.include?(value_string),
                  id: id,
                  data: { checkbox_group_item: group_name }
                ),
                view_context.content_tag(:span, label)
              ])
            end
          end

          view_context.content_tag(:td) do
            view_context.content_tag(:div, data: { checkbox_group: group_name }) do
              view_context.content_tag(:div, view_context.safe_join(controls), class: "filter-checkbox-group__options")
            end
          end
        end

        def clear_cell(view_context)
          group_name = (options[:group] || name).to_s.dasherize
          return view_context.checkbox_group_action_cell(target: group_name) if view_context.respond_to?(:checkbox_group_action_cell)

          super
        end
      end

      class DatetimeRange < Base
        def row(view_context, form, scope, current_values, locals)
          view_context.content_tag(:tr) do
            view_context.safe_join([
              label_cell(view_context, form, locals),
              view_context.content_tag(:td, range_inputs(view_context, scope, current_values, locals)),
              clear_cell(view_context)
            ])
          end
        end

        private

        def range_inputs(view_context, scope, current_values, locals)
          from_name = (options[:from] || :"start_#{name}").to_sym
          to_name = (options[:to] || :"end_#{name}").to_sym
          css_class = evaluate_option(options[:css_class] || "#{scope}_#{name}", view_context, locals)

          view_context.safe_join([
            view_context.render(
              "yummy_guide/administrate/filter_forms/datetime_field",
              form_scope: scope,
              field_name: from_name,
              current_value: current_values[from_name.to_s],
              css_class: css_class,
              end_target: to_name
            ),
            view_context.content_tag(:p, "〜", class: "filter-datetime-range-separator"),
            view_context.render(
              "yummy_guide/administrate/filter_forms/datetime_field",
              form_scope: scope,
              field_name: to_name,
              current_value: current_values[to_name.to_s],
              css_class: css_class,
              end_of_day: true
            )
          ])
        end
      end

      class DateRange < Base
        def row(view_context, form, _scope, current_values, locals)
          from_name = (options[:from] || :"start_#{name}").to_sym
          to_name = (options[:to] || :"end_#{name}").to_sym

          view_context.content_tag(:tr) do
            view_context.safe_join([
              label_cell(view_context, form, locals),
              view_context.content_tag(:td) do
                view_context.safe_join([
                  form.date_field(from_name, value: current_values[from_name.to_s].presence || evaluate_option(options[:from_default], view_context, locals)),
                  view_context.content_tag(:span, "〜"),
                  form.date_field(to_name, value: current_values[to_name.to_s].presence || evaluate_option(options[:to_default], view_context, locals))
                ])
              end,
              clear_cell(view_context)
            ])
          end
        end
      end

      class DatetimeLocalRange < Base
        def row(view_context, form, _scope, current_values, locals)
          from_name = (options[:from] || :"start_#{name}").to_sym
          to_name = (options[:to] || :"end_#{name}").to_sym

          view_context.content_tag(:tr) do
            view_context.safe_join([
              label_cell(view_context, form, locals),
              view_context.content_tag(:td) do
                view_context.safe_join([
                  form.datetime_local_field(from_name, value: current_values[from_name.to_s].presence || evaluate_option(options[:from_default], view_context, locals)),
                  view_context.content_tag(:p, "〜", style: "text-align: center; margin: 0;"),
                  form.datetime_local_field(to_name, value: current_values[to_name.to_s].presence || evaluate_option(options[:to_default], view_context, locals))
                ])
              end,
              clear_cell(view_context)
            ])
          end
        end
      end

      class Custom < Base
        def row(view_context, form, scope, current_values, locals)
          view_context.render(
            options.fetch(:partial),
            form: form,
            form_scope: scope,
            field: self,
            current_values: current_values,
            filter_locals: locals
          )
        end
      end

      module Resolver
        module_function

        def attributes_for(dashboard)
          source = dashboard.respond_to?(:filter_attributes) ? dashboard.filter_attributes : constant_value(dashboard, :FILTER_ATTRIBUTES)
          normalize_attributes(source || {})
        end

        def normalize_attributes(attributes)
          attributes.to_h.map do |name, field|
            [name.to_sym, normalize_field(name, field)]
          end.to_h
        end

        def normalize_field(name, field)
          if field.respond_to?(:with_name)
            field.with_name(name)
          elsif field.is_a?(Class) && field < Base
            field.with_options.with_name(name)
          else
            raise ArgumentError, "Unsupported filter field for #{name}: #{field.inspect}"
          end
        end

        def constant_value(dashboard, name)
          target = dashboard.is_a?(Class) ? dashboard : dashboard.class
          target.const_get(name, false) if target.const_defined?(name, false)
        end
      end
    end
  end
end
