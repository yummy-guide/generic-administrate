# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "yummy/guide/generic/administrate" do
  it "Bundler の自動 require 互換パスから engine を読み込めること" do
    # Gem 名から導かれる require パスで engine まで初期化できることを検証する。
    stdout, stderr, status = Open3.capture3(
      {
        "BUNDLE_GEMFILE" => File.expand_path("../../../../Gemfile", __dir__)
      },
      RbConfig.ruby,
      "-rbundler/setup",
      "-I",
      File.expand_path("../../../../lib", __dir__),
      "-e",
      'require "yummy/guide/generic/administrate"; puts Administrate::Engine.name'
    )

    expect(status.success?).to be(true), stderr
    expect(stdout.strip).to eq("Administrate::Engine")
  end
end
