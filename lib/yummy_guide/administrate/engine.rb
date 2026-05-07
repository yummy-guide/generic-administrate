# frozen_string_literal: true

module YummyGuide
  module Administrate
    class Engine < ::Rails::Engine
      initializer "yummy_guide.administrate.assets" do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.precompile += %w[
          yummy_guide_administrate/components.css
          yummy_guide_administrate/filter_form.js
          yummy_guide_administrate/sticky_left_columns.js
        ]
      end
    end
  end
end

