# frozen_string_literal: true

module YummyGuide
  module Administrate
    class Engine < ::Rails::Engine
      initializer "yummy_guide.administrate.assets" do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.precompile += %w[
          yummy_guide_administrate/components.css
          yummy_guide_administrate/clipboards.js
          yummy_guide_administrate/column_resizer.js
          yummy_guide_administrate/datetime_input.js
          yummy_guide_administrate/fixed_submit_actions.js
          yummy_guide_administrate/filter_controls.js
          yummy_guide_administrate/filter_form.js
          yummy_guide_administrate/tooltips.js
          yummy_guide_administrate/resizable_navigation.js
        ]
      end

      initializer "yummy_guide.administrate.helpers" do |app|
        app.config.to_prepare do
          next unless defined?(::Administrate::ApplicationController)

          ::Administrate::ApplicationController.helper YummyGuide::Administrate::NumberInputHelper
          ::Administrate::ApplicationController.helper YummyGuide::Administrate::FilterFormHelper
          ::Administrate::ApplicationController.helper YummyGuide::Administrate::FilterControlsHelper
          ::Administrate::ApplicationController.helper YummyGuide::Administrate::TooltipHelper
        end
      end
    end
  end
end
