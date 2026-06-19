# frozen_string_literal: true

module YummyGuide
  module Administrate
    module CollectionHelper
      COLLECTION_CELL_COPY_BLOCK_TAGS = %w[
        address article aside blockquote div dl dt dd fieldset figcaption figure footer
        form h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table tr ul
      ].freeze
      DEFAULT_FIXED_COLUMN_WIDTHS = {
        id: "4rem",
        month: "6rem",
        assign_group_id: "6rem",
        reservation_type: "7rem",
        short_access_id: "8rem",
        customer: "12rem"
      }.freeze
      DEFAULT_FIXED_COLUMN_WIDTH = "8rem"
      CONTENT_WIDTH_VALUE = "max-content"
      COPY_CELL_ACTION_WIDTH_OFFSET = "var(--admin-copy-cell-width-offset, 1.85rem)"
      MAX_MOBILE_FIXED_COLUMNS_COUNT = 1

      CollectionTableDefinition = Struct.new(
        :column_names,
        :fixed_columns_count,
        :mobile_fixed_columns_count,
        :sticky_columns,
        :table_style,
        :grid_template_columns,
        :column_ids,
        :actions_column_id,
        :adjusted_column_indexes,
        :colgroup_widths,
        keyword_init: true
      ) do
        def sticky_column(column_name)
          sticky_columns[column_name.to_sym] || {}
        end

        def column_id(column_name)
          column_ids[column_name.to_sym]
        end
      end

      def yummy_guide_administrate_collection_table_definition(page:, collection_presenter:, column_names: nil, column_width_storage_scope: nil)
        names = (column_names || collection_presenter.attribute_types.keys).map(&:to_sym)
        widths = yummy_guide_administrate_collection_fixed_column_widths(page: page)
        column_ids = names.index_with do |name|
          yummy_guide_administrate_collection_column_id(collection_presenter, name)
        end
        resolved_column_width_storage_scope = yummy_guide_administrate_collection_column_width_storage_scope(column_width_storage_scope)
        saved_column_widths = yummy_guide_administrate_collection_saved_column_widths(resolved_column_width_storage_scope)
        default_column_widths = yummy_guide_administrate_collection_default_column_widths(page: page)

        CollectionTableDefinition.new(
          column_names: names,
          fixed_columns_count: yummy_guide_administrate_collection_table_fixed_columns_count_for_names(
            page: page,
            column_names: names
          ),
          mobile_fixed_columns_count: yummy_guide_administrate_collection_table_mobile_fixed_columns_count_for_names(
            page: page,
            column_names: names
          ),
          sticky_columns: yummy_guide_administrate_collection_sticky_columns(
            page: page,
            collection_presenter: collection_presenter,
            column_names: names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          ),
          table_style: yummy_guide_administrate_collection_table_style(
            page: page,
            column_names: names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          ),
          grid_template_columns: yummy_guide_administrate_collection_grid_template_columns(
            column_names: names,
            widths: widths
          ),
          column_ids: column_ids,
          actions_column_id: yummy_guide_administrate_collection_actions_column_id(collection_presenter),
          adjusted_column_indexes: yummy_guide_administrate_collection_adjusted_column_indexes(
            column_names: names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          ),
          colgroup_widths: yummy_guide_administrate_collection_colgroup_widths(
            column_names: names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          )
        )
      end

      def yummy_guide_administrate_collection_table_fixed_columns_count(page:, collection_presenter:)
        yummy_guide_administrate_collection_fixed_columns_count_for(
          page: page,
          collection_presenter: collection_presenter,
          method_name: :index_fixed_columns_count
        )
      end

      def yummy_guide_administrate_collection_table_mobile_fixed_columns_count(page:, collection_presenter:)
        [
          yummy_guide_administrate_collection_fixed_columns_count_for(
            page: page,
            collection_presenter: collection_presenter,
            method_name: :index_mobile_fixed_columns_count
          ),
          MAX_MOBILE_FIXED_COLUMNS_COUNT
        ].min
      rescue NoMethodError
        0
      end

      def yummy_guide_administrate_collection_table_fixed_columns_count_for_names(page:, column_names:)
        yummy_guide_administrate_collection_fixed_columns_count_for_names(
          page: page,
          column_names: column_names.map(&:to_sym),
          method_name: :index_fixed_columns_count
        )
      end

      def yummy_guide_administrate_collection_table_mobile_fixed_columns_count_for_names(page:, column_names:)
        [
          yummy_guide_administrate_collection_fixed_columns_count_for_names(
            page: page,
            column_names: column_names.map(&:to_sym),
            method_name: :index_mobile_fixed_columns_count
          ),
          MAX_MOBILE_FIXED_COLUMNS_COUNT
        ].min
      rescue NoMethodError
        0
      end

      def yummy_guide_administrate_collection_sticky_columns(page:, collection_presenter:, column_names:, column_ids: nil, default_column_widths: {}, saved_column_widths: {})
        names = column_names.map(&:to_sym)
        fixed_count = yummy_guide_administrate_collection_fixed_columns_count_for_names(
          page: page,
          column_names: names,
          method_name: :index_fixed_columns_count
        )
        mobile_fixed_count = yummy_guide_administrate_collection_table_mobile_fixed_columns_count_for_names(
          page: page,
          column_names: names
        )
        max_count = [fixed_count, mobile_fixed_count].max
        return {} if max_count.zero?

        base_widths = yummy_guide_administrate_collection_fixed_column_widths(page: page)
        column_ids ||= names.index_with do |name|
          if collection_presenter.respond_to?(:resource_name)
            yummy_guide_administrate_collection_column_id(collection_presenter, name)
          else
            name.to_s
          end
        end
        widths = yummy_guide_administrate_collection_effective_column_widths(
          column_names: names,
          column_ids: column_ids,
          base_widths: base_widths,
          default_column_widths: default_column_widths,
          saved_column_widths: saved_column_widths
        )
        desktop_lefts = yummy_guide_administrate_collection_sticky_lefts(names.first(fixed_count), widths)
        mobile_lefts = yummy_guide_administrate_collection_sticky_lefts(names.first(mobile_fixed_count), widths)

        names.first(max_count).each_with_index.each_with_object({}) do |(name, index), sticky_columns|
          classes = []
          styles = []
          width = widths.fetch(name, yummy_guide_administrate_collection_default_fixed_column_width)

          if index < fixed_count
            classes << "sticky-left"
            classes << "sticky-left--last" if index == fixed_count - 1
            styles << "--sticky-left: #{desktop_lefts.fetch(name)}"
            styles << "--sticky-width: #{width}"
          end

          if index < mobile_fixed_count
            classes << "sticky-left-mobile"
            classes << "sticky-left-mobile--last" if index == mobile_fixed_count - 1
            styles << "--sticky-mobile-left: #{mobile_lefts.fetch(name)}"
            styles << "--sticky-mobile-width: #{width}"
          end

          sticky_columns[name] = {
            class: classes.join(" "),
            style: styles.join("; ")
          }
        end
      end

      def yummy_guide_administrate_collection_sticky_table_style(page:, column_names:, column_ids: nil, default_column_widths: {}, saved_column_widths: {})
        names = column_names.map(&:to_sym)
        base_widths = yummy_guide_administrate_collection_fixed_column_widths(page: page)
        column_ids ||= names.index_with { |name| name.to_s }
        widths = yummy_guide_administrate_collection_effective_column_widths(
          column_names: names,
          column_ids: column_ids,
          base_widths: base_widths,
          default_column_widths: default_column_widths,
          saved_column_widths: saved_column_widths
        )

        names.first(6).each_with_index.flat_map do |name, index|
          width = widths.fetch(name, yummy_guide_administrate_collection_default_fixed_column_width)
          column_number = index + 1

          [
            "--admin-sticky-col-#{column_number}-width: #{width}",
            "--admin-sticky-mobile-col-#{column_number}-width: #{width}"
          ]
        end.join("; ")
      end

      def yummy_guide_administrate_collection_table_style(page:, column_names:, column_ids:, default_column_widths:, saved_column_widths:)
        [
          yummy_guide_administrate_collection_sticky_table_style(
            page: page,
            column_names: column_names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          ),
          yummy_guide_administrate_collection_resizable_table_style(
            column_names: column_names,
            column_ids: column_ids,
            default_column_widths: default_column_widths,
            saved_column_widths: saved_column_widths
          )
        ].reject(&:blank?).join("; ")
      end

      def yummy_guide_administrate_collection_column_id(collection_presenter, column_name)
        [
          collection_presenter.resource_name,
          column_name
        ].map { |segment| segment.to_s.parameterize(separator: "_") }.join(".")
      end

      def yummy_guide_administrate_collection_actions_column_id(collection_presenter)
        yummy_guide_administrate_collection_column_id(collection_presenter, :actions)
      end

      def yummy_guide_administrate_build_collection_cell(content:, present_path: nil, target: nil, reference_link: false, text_link: false, leading_actions: nil, copy_text: nil, copy_text_transform: nil)
        normalized_content = yummy_guide_administrate_collection_cell_content(content)

        {
          content: yummy_guide_administrate_collection_cell_content_with_copy_frame(
            normalized_content,
            content_href: text_link ? present_path : nil,
            reference_href: reference_link ? present_path : nil,
            target: target,
            leading_actions: leading_actions,
            copy_text: copy_text,
            copy_text_transform: copy_text_transform
          ),
          linkable: false
        }
      end

      def yummy_guide_administrate_safe_transliterate_copy_text(text)
        transliterated = ActiveSupport::Inflector.transliterate(text)
        return text if transliterated.count("?") > text.count("?")

        transliterated
      end

      def yummy_guide_administrate_collection_detail_path(resource, namespace:)
        return if resource.blank?
        return if respond_to?(:accessible_action?) && !accessible_action?(resource, :show)

        polymorphic_path([namespace, resource])
      rescue StandardError
        nil
      end

      def yummy_guide_administrate_collection_attribute_path(attribute:, resource:, namespace:)
        if yummy_guide_administrate_collection_reference_link?(attribute)
          yummy_guide_administrate_collection_detail_path(attribute.data, namespace: namespace)
        elsif yummy_guide_administrate_collection_text_link?(attribute)
          yummy_guide_administrate_collection_detail_path(resource, namespace: namespace)
        end
      end

      def yummy_guide_administrate_collection_reference_link?(attribute)
        attribute.is_a?(::Administrate::Field::BelongsTo) && attribute.data.present?
      end

      def yummy_guide_administrate_collection_text_link?(attribute)
        attribute.respond_to?(:name) && attribute.name.to_s == "id"
      end

      def yummy_guide_administrate_collection_wrap(content, href:)
        yummy_guide_administrate_collection_link(content, href: href)
      end

      def yummy_guide_administrate_collection_actions_partial(partial_name)
        if controller.respond_to?(:controller_path)
          controller_partial = "#{controller.controller_path}/#{partial_name}"
          return controller_partial if lookup_context.exists?(controller_partial, [], true)
        end

        "administrate/application/#{partial_name}"
      end

      private

      def yummy_guide_administrate_collection_fixed_columns_count_for(page:, collection_presenter:, method_name:)
        return 0 unless page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)

        dashboard = page.instance_variable_get(:@dashboard)
        return 0 unless dashboard&.class&.respond_to?(method_name)

        fixed_columns_count = dashboard.class.public_send(method_name).to_i
        fixed_columns_count = 0 if fixed_columns_count.negative?

        attribute_count = collection_presenter.attribute_types.size
        [fixed_columns_count, attribute_count].min
      rescue NoMethodError
        0
      end

      def yummy_guide_administrate_collection_fixed_columns_count_for_names(page:, column_names:, method_name:)
        return 0 unless page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)

        dashboard = page.instance_variable_get(:@dashboard)
        return 0 unless dashboard&.class&.respond_to?(method_name)

        fixed_columns_count = dashboard.class.public_send(method_name).to_i
        fixed_columns_count = 0 if fixed_columns_count.negative?

        [fixed_columns_count, column_names.size].min
      rescue NoMethodError
        0
      end

      def yummy_guide_administrate_collection_fixed_column_widths(page:)
        configured_widths =
          if page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)
            dashboard = page.instance_variable_get(:@dashboard)
            dashboard.class.index_fixed_column_widths if dashboard&.class&.respond_to?(:index_fixed_column_widths)
          end

        raw_widths = DEFAULT_FIXED_COLUMN_WIDTHS.merge(
          (configured_widths || {}).to_h.each_with_object({}) do |(name, width), widths|
            next if width.nil?

            widths[name.to_sym] = yummy_guide_administrate_collection_column_width_value(width)
          end
        )

        raw_widths.transform_values do |width|
          yummy_guide_administrate_collection_fixed_column_width_value(width)
        end
      end

      def yummy_guide_administrate_collection_default_column_widths(page:)
        configured_widths =
          if page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)
            dashboard = page.instance_variable_get(:@dashboard)
            dashboard.class.index_default_column_widths if dashboard&.class&.respond_to?(:index_default_column_widths)
          end

        (configured_widths || {}).to_h.each_with_object({}) do |(name, width), widths|
          next if width.nil?

          value = yummy_guide_administrate_collection_column_width_value(width)
          next if value == CONTENT_WIDTH_VALUE

          widths[name.to_sym] = yummy_guide_administrate_collection_default_column_width_value(value)
        end
      end

      def yummy_guide_administrate_collection_column_width_storage_scope(column_width_storage_scope)
        column_width_storage_scope.presence ||
          (request.path if respond_to?(:request) && request.respond_to?(:path))
      end

      def yummy_guide_administrate_collection_saved_column_widths(column_width_storage_scope)
        return {} if column_width_storage_scope.blank?

        if respond_to?(:yummy_guide_administrate_admin_browser_column_widths)
          yummy_guide_administrate_admin_browser_column_widths(column_width_storage_scope)
        elsif respond_to?(:controller) && controller.respond_to?(:yummy_guide_administrate_admin_browser_column_widths)
          controller.yummy_guide_administrate_admin_browser_column_widths(column_width_storage_scope)
        else
          {}
        end
      end

      def yummy_guide_administrate_collection_resizable_table_style(column_names:, column_ids:, default_column_widths:, saved_column_widths:)
        column_names.map(&:to_sym).each_with_index.flat_map do |name, index|
          column_number = index + 1
          column_id = column_ids[name].to_s
          default_width = default_column_widths[name]
          saved_width = yummy_guide_administrate_collection_saved_column_width(saved_column_widths, column_id)
          saved_width = yummy_guide_administrate_collection_css_pixel_value(saved_width) if saved_width.present?
          next [] if default_width.blank? && saved_width.blank?

          styles = []
          styles << "--admin-column-resizer-default-col-#{column_number}: #{default_width}" if default_width.present?
          styles << "--admin-column-resizer-user-col-#{column_number}: #{saved_width}" if saved_width.present?
          styles << "--admin-column-resizer-col-#{column_number}: #{yummy_guide_administrate_collection_effective_column_width_value(column_number, default_width: default_width)}"
          styles
        end.flatten.join("; ")
      end

      def yummy_guide_administrate_collection_effective_column_width_value(column_number, default_width:)
        user_width = "var(--admin-column-resizer-user-col-#{column_number})"
        return user_width if default_width.blank?

        "var(--admin-column-resizer-user-col-#{column_number}, var(--admin-column-resizer-default-col-#{column_number}))"
      end

      def yummy_guide_administrate_collection_adjusted_column_indexes(column_names:, column_ids:, default_column_widths:, saved_column_widths:)
        column_names.map(&:to_sym).each_with_index.filter_map do |name, index|
          column_id = column_ids[name].to_s
          next unless default_column_widths[name].present? || yummy_guide_administrate_collection_saved_column_width(saved_column_widths, column_id).present?

          index + 1
        end
      end

      def yummy_guide_administrate_collection_colgroup_widths(column_names:, column_ids:, default_column_widths:, saved_column_widths:)
        column_names.map(&:to_sym).map do |name|
          column_id = column_ids[name].to_s
          saved_width = yummy_guide_administrate_collection_saved_column_width(saved_column_widths, column_id)
          next yummy_guide_administrate_collection_css_pixel_value(saved_width) if saved_width.present?

          default_column_widths[name].presence
        end
      end

      def yummy_guide_administrate_collection_effective_column_widths(column_names:, column_ids:, base_widths:, default_column_widths:, saved_column_widths:)
        column_names.map(&:to_sym).each_with_object(base_widths.dup) do |name, widths|
          column_id = column_ids[name].to_s
          saved_width = yummy_guide_administrate_collection_saved_column_width(saved_column_widths, column_id)

          if saved_width.present?
            widths[name] = yummy_guide_administrate_collection_css_pixel_value(saved_width)
          elsif default_column_widths[name].present?
            widths[name] = default_column_widths[name]
          end
        end
      end

      def yummy_guide_administrate_collection_saved_column_width(saved_column_widths, column_id)
        saved_column_widths[column_id] || saved_column_widths[column_id.to_sym]
      end

      def yummy_guide_administrate_collection_css_pixel_value(value)
        numeric_value = value.to_f
        rounded_value = (numeric_value * 1000).round / 1000.0
        rounded_value == rounded_value.to_i ? "#{rounded_value.to_i}px" : "#{rounded_value}px"
      end

      def yummy_guide_administrate_collection_grid_template_columns(column_names:, widths:)
        column_names.map(&:to_sym).map do |name|
          widths.fetch(name, CONTENT_WIDTH_VALUE)
        end.join(" ")
      end

      def yummy_guide_administrate_collection_column_width_value(width)
        return CONTENT_WIDTH_VALUE if width.respond_to?(:to_sym) && width.to_sym == :content

        width.to_s
      end

      def yummy_guide_administrate_collection_default_column_width_value(width)
        yummy_guide_administrate_collection_column_width_value_with_copy_action(width)
      end

      def yummy_guide_administrate_collection_fixed_column_width_value(width)
        yummy_guide_administrate_collection_column_width_value_with_copy_action(width)
      end

      def yummy_guide_administrate_collection_column_width_value_with_copy_action(width)
        return width if width == CONTENT_WIDTH_VALUE

        "calc(#{width} + #{COPY_CELL_ACTION_WIDTH_OFFSET})"
      end

      def yummy_guide_administrate_collection_default_fixed_column_width
        yummy_guide_administrate_collection_fixed_column_width_value(DEFAULT_FIXED_COLUMN_WIDTH)
      end

      def yummy_guide_administrate_collection_sticky_lefts(column_names, widths)
        current_parts = []

        column_names.each_with_object({}) do |name, lefts|
          lefts[name] = yummy_guide_administrate_collection_css_sum(current_parts)
          current_parts << widths.fetch(name, yummy_guide_administrate_collection_default_fixed_column_width)
        end
      end

      def yummy_guide_administrate_collection_css_sum(parts)
        return "0px" if parts.empty?
        return parts.first if parts.one?

        "calc(#{parts.join(" + ")})"
      end

      def yummy_guide_administrate_collection_link(content, href:, target: nil, html_class: "action-show", aria: nil, data: nil)
        return content if href.blank?

        link_options = { class: html_class }
        if target.present?
          link_options[:target] = target
          link_options[:rel] = "noopener noreferrer" if target == "_blank"
        end
        link_options[:aria] = aria if aria.present?
        link_options[:data] = data if data.present?

        link_to(href, **link_options) { content }
      end

      def yummy_guide_administrate_collection_cell_content(rendered_content)
        text = rendered_content.to_s
        return text.html_safe unless text.include?("<a")

        fragment = Nokogiri::HTML.fragment(text)
        fragment.css("a").each do |link|
          next if yummy_guide_administrate_preserve_collection_cell_link?(link)

          link.replace(link.children)
        end

        fragment.to_html.html_safe
      end

      def yummy_guide_administrate_collection_cell_content_with_copy_frame(content, content_href: nil, reference_href: nil, target: nil, leading_actions: nil, copy_text: nil, copy_text_transform: nil)
        resolved_copy_text =
          if copy_text.nil?
            yummy_guide_administrate_collection_cell_copy_text(content, copy_text_transform: copy_text_transform)
          else
            yummy_guide_administrate_normalize_collection_cell_copy_text(copy_text.to_s).yield_self do |text|
              next text if copy_text_transform.blank? || text.blank?

              copy_text_transform.call(text)
            end
          end

        linked_content =
          if content_href.present?
            yummy_guide_administrate_collection_link(
              content,
              href: content_href,
              target: target,
              html_class: "admin-copy-cell__content-link",
              data: { behavior: "preserve-collection-link" }
            )
          else
            content
          end

        reference_link =
          if reference_href.present?
            yummy_guide_administrate_collection_link(
              tag.span(class: "admin-copy-cell__link-icon", aria: { hidden: true }),
              href: reference_href,
              target: target,
              html_class: "admin-copy-cell__link",
              aria: { label: "Open detail page" },
              data: { behavior: "reference-cell-link" }
            )
          end

        copy_button =
          if resolved_copy_text.present?
            button_tag(
              type: "button",
              class: "admin-copy-cell__button",
              data: {
                behavior: "copy-cell",
                copy_text: resolved_copy_text
              },
              aria: {
                label: "Copy cell value"
              }
            ) do
              tag.span(class: "admin-copy-cell__icon", aria: { hidden: true })
            end
          end

        content_tag(:span, class: "admin-copy-cell") do
          safe_join([
            content_tag(:span, linked_content, class: "admin-copy-cell__content"),
            content_tag(:span, safe_join([leading_actions, reference_link, copy_button].compact), class: "admin-copy-cell__actions"),
            content_tag(
              :span,
              "",
              class: "admin-copy-cell__feedback",
              data: { role: "copy-feedback" },
              aria: { live: "polite" }
            )
          ])
        end
      end

      def yummy_guide_administrate_collection_cell_copy_text(content, copy_text_transform: nil)
        raw_content = content.to_s
        text =
          if raw_content.include?("<")
            fragment = Nokogiri::HTML.fragment(raw_content)
            fragment.css("button, input, select, textarea, form, script, style, [aria-hidden='true'], [hidden]").remove
            yummy_guide_administrate_normalize_collection_cell_copy_text(
              yummy_guide_administrate_collection_cell_text_content(fragment)
            )
          else
            yummy_guide_administrate_normalize_collection_cell_copy_text(raw_content)
          end

        return text if copy_text_transform.blank?

        copy_text_transform.call(text)
      end

      def yummy_guide_administrate_preserve_collection_cell_link?(link)
        link["data-behavior"].to_s.split.include?("preserve-collection-link")
      end

      def yummy_guide_administrate_collection_cell_text_content(node)
        node.children.map { |child| yummy_guide_administrate_collection_cell_text_node(child) }.join
      end

      def yummy_guide_administrate_collection_cell_text_node(node)
        case node
        when Nokogiri::XML::Text
          node.text
        when Nokogiri::XML::Element
          return "\n" if node.name == "br"

          text = yummy_guide_administrate_collection_cell_text_content(node)
          yummy_guide_administrate_collection_cell_copy_block_element?(node) ? "#{text}\n" : text
        else
          ""
        end
      end

      def yummy_guide_administrate_collection_cell_copy_block_element?(node)
        COLLECTION_CELL_COPY_BLOCK_TAGS.include?(node.name)
      end

      def yummy_guide_administrate_normalize_collection_cell_copy_text(text)
        text
          .gsub(/\u00A0/, " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t\f\v]+\n/, "\n")
          .gsub(/\n[ \t\f\v]+/, "\n")
          .gsub(/\n{2,}/, "\n")
          .strip
      end
    end
  end
end
