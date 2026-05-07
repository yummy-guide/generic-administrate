# frozen_string_literal: true

module YummyGuide
  module Administrate
    module CollectionHelper
      COLLECTION_CELL_COPY_BLOCK_TAGS = %w[
        address article aside blockquote div dl dt dd fieldset figcaption figure footer
        form h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table tr ul
      ].freeze

      def yummy_guide_administrate_collection_table_fixed_columns_count(page:, collection_presenter:)
        return 0 unless page.respond_to?(:instance_variable_defined?) && page.instance_variable_defined?(:@dashboard)

        dashboard = page.instance_variable_get(:@dashboard)
        return 0 unless dashboard&.class&.respond_to?(:index_fixed_columns_count)

        fixed_columns_count = dashboard.class.index_fixed_columns_count.to_i
        fixed_columns_count = 0 if fixed_columns_count.negative?

        attribute_count = collection_presenter.attribute_types.size
        [fixed_columns_count, attribute_count].min
      rescue NoMethodError
        0
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
