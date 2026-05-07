# frozen_string_literal: true

require_relative "lib/yg/administrate/version"

Gem::Specification.new do |spec|
  spec.name = "yg-administrate"
  spec.version = Yg::Administrate::VERSION
  spec.authors = ["OpenAI Codex"]
  spec.email = ["support@example.com"]

  spec.summary = "Shared Administrate extensions for Yummy Guide Rails apps"
  spec.description = "Rails Engine that provides shared Administrate dashboards, helpers, fields, partials, and assets."
  spec.homepage = "https://github.com/akatsuki-kk/yg-administrate"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "{app,lib,spec}/**/*",
      "Gemfile",
      "README.md",
      "Rakefile",
      "yg-administrate.gemspec"
    ]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "administrate", ">= 0.19", "< 0.21"
  spec.add_dependency "rails", ">= 7.0", "< 7.2"
  spec.add_dependency "sprockets-rails"

  spec.add_development_dependency "rspec", "~> 3.13"
end
