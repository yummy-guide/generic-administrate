# frozen_string_literal: true

module YummyGuide
  module Administrate
    class << self
      attr_accessor :admin_browser_preferences_redis
    end
  end
end

require "rails"
require "administrate"

require_relative "../../app/helpers/yummy_guide/administrate/number_input_helper"
require_relative "../../app/helpers/yummy_guide/administrate/filter_form_helper"
require_relative "../../app/helpers/yummy_guide/administrate/filter_controls_helper"
require_relative "../../app/helpers/yummy_guide/administrate/tooltip_helper"
require_relative "administrate/version"
require_relative "administrate/filters"
require_relative "administrate/browser_preference_store"
require_relative "administrate/engine"

module YummyGuide
  module Administrate
  end
end
