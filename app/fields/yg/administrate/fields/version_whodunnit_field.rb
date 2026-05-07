# frozen_string_literal: true

module Yg
  module Administrate
    module Fields
      class VersionWhodunnitField < ::Administrate::Field::Base
        def self.field_type
          "yg_administrate/version_whodunnit_field"
        end

        def user
          @user ||= user_class&.find_by(id: data)
        end

        def label
          return if data.blank?

          if user.present?
            custom_label = options[:user_label]
            return custom_label.call(user) if custom_label.respond_to?(:call)

            if defined?(::UserDashboard)
              dashboard = ::UserDashboard.new
              return dashboard.display_resource(user) if dashboard.respond_to?(:display_resource)
            end

            return user.full_name if user.respond_to?(:full_name) && user.full_name.present?
            return user.name if user.respond_to?(:name) && user.name.present?

            "#{user.class.model_name.human} ##{user.id}"
          else
            "User ##{data}"
          end
        end

        def path
          return if user.blank?

          Rails.application.routes.url_helpers.polymorphic_path([namespace, user])
        rescue StandardError
          nil
        end

        def linkable?
          path.present?
        end

        private

        def namespace
          options.fetch(:namespace, :admin)
        end

        def user_class
          candidate = options[:user_class]
          return candidate if candidate.is_a?(Class)
          return candidate.safe_constantize if candidate.respond_to?(:safe_constantize)

          ::User if defined?(::User)
        end
      end
    end
  end
end

