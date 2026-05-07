# frozen_string_literal: true

module Yg
  module Administrate
    class Engine < ::Rails::Engine
      initializer "yg.administrate.assets" do |app|
        next unless app.config.respond_to?(:assets)

        app.config.assets.precompile += %w[
          yg_administrate/components.css
          yg_administrate/filter_form.js
          yg_administrate/sticky_left_columns.js
        ]
      end
    end
  end
end

