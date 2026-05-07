# frozen_string_literal: true

require "administrate/field/base"

module YummyGuide
  module Administrate
    module Fields
      module Area
        class PictureField < ::Administrate::Field::Base
          def self.field_type
            "yummy_guide_administrate/area/picture"
          end

          def attachments
            @attachments ||=
              if data.respond_to?(:attachments)
                data.attachments.to_a
              elsif data.respond_to?(:attached?) && data.attached?
                [data]
              else
                []
              end
          end

          def max_uploads
            resolved = resolve_option(:max_uploads)
            resolved = resource.class::MAX_PICTURE_UPLOADS if resolved.blank? && resource.class.const_defined?(:MAX_PICTURE_UPLOADS)
            resolved = attachments.size + 1 if resolved.blank?

            [resolved.to_i, 1].max
          end

          def input_name
            resolve_option(:input_name) || "#{resource_param_key}[#{attribute}][]"
          end

          def purge_input_name
            resolve_option(:purge_input_name) || "#{resource_param_key}[#{attribute}_purge_ids][]"
          end

          def attachment_label(attachment)
            return attachment.filename.to_s if attachment.respond_to?(:filename)

            attachment.to_s
          end

          def attachment_identifier(attachment)
            return attachment.id if attachment.respond_to?(:id) && attachment.id.present?
            return attachment.blob_id if attachment.respond_to?(:blob_id) && attachment.blob_id.present?

            nil
          end

          def attachment_url(attachment, view_context:)
            resolve_attachment_url(:attachment_url, attachment, view_context: view_context) || preview_url(attachment, view_context: view_context)
          end

          def preview_url(attachment, view_context:)
            resolve_attachment_url(:preview_url, attachment, view_context: view_context) || default_attachment_url(attachment, view_context: view_context)
          end

          private

          def resource_param_key
            resource.class.model_name.param_key
          end

          def resolve_option(name)
            option = options[name]
            if option.respond_to?(:call)
              return option.call if option.arity.zero?
              return option.call(resource) if option.arity == 1

              return option.call(resource, attribute, data)
            end

            option
          end

          def resolve_attachment_url(name, attachment, view_context:)
            resolver = options[name]
            return unless resolver.respond_to?(:call)

            case resolver.arity
            when 0
              resolver.call
            when 1
              resolver.call(attachment)
            else
              resolver.call(attachment, view_context)
            end
          end

          def default_attachment_url(attachment, view_context:)
            return attachment.url if attachment.respond_to?(:url)
            return view_context.rails_blob_path(attachment, only_path: true) if attachment.respond_to?(:blob)

            nil
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
