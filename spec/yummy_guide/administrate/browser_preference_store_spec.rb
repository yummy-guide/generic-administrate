# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::BrowserPreferenceStore do
  class FakeAdminBrowserPreferenceRedis
    attr_reader :expires, :sets

    def initialize(values = {})
      @values = values.dup
      @expires = {}
      @sets = []
    end

    def get(key)
      @values[key]
    end

    def expire(key, ttl)
      @expires[key] = ttl
    end

    def set(key, value, ex:)
      @values[key] = value
      @expires[key] = ex
      @sets << [key, JSON.parse(value), ex]
    end
  end

  class FailingAdminBrowserPreferenceRedis
    def get(_key)
      raise StandardError, "connection failed"
    end
  end

  let(:redis) { FakeAdminBrowserPreferenceRedis.new }
  let(:store) { described_class.new(redis: redis, key_prefix: "test:admin_preferences") }

  describe "#fetch" do
    # 既存設定を読み込むたびにRedisキーのTTLを30日へ延長することを確認する
    it "refreshes the TTL when a preference exists" do
      key = "test:admin_preferences:browser-1"
      redis = FakeAdminBrowserPreferenceRedis.new(
        key => JSON.generate(
          "navigation_width" => 180,
          "column_widths" => { "/admin/workers" => { "worker.name" => 240 } }
        )
      )
      store = described_class.new(redis: redis, key_prefix: "test:admin_preferences")

      state = store.fetch("browser-1")

      expect(state["navigation_width"]).to eq(180.0)
      expect(state.dig("column_widths", "/admin/workers", "worker.name")).to eq(240.0)
      expect(redis.expires[key]).to eq(described_class::TTL_SECONDS)
    end

    # Redis接続エラーはcontroller層で扱える専用例外へ変換されることを確認する
    it "wraps redis errors as RedisUnavailable" do
      store = described_class.new(redis: FailingAdminBrowserPreferenceRedis.new, key_prefix: "test:admin_preferences")

      expect { store.fetch("browser-1") }.to raise_error(described_class::RedisUnavailable, "connection failed")
    end
  end

  describe "#update" do
    # ナビゲーション幅を保存するとRedisへ30日TTL付きで書き込まれることを確認する
    it "stores a navigation width with a TTL" do
      state = store.update("browser-1", { "preference" => "navigation_width", "width" => "190.4" })

      expect(state["navigation_width"]).to eq(190.4)
      expect(redis.sets.last).to eq([
        "test:admin_preferences:browser-1",
        { "navigation_width" => 190.4, "column_widths" => {} },
        described_class::TTL_SECONDS
      ])
    end

    # カラム幅はscopeとcolumn_idの組み合わせで保存されることを確認する
    it "stores a column width under the requested scope" do
      state = store.update(
        "browser-1",
        {
          "preference" => "column_width",
          "scope" => "/admin/workers",
          "column_id" => "worker.interview_summary",
          "width" => "800"
        }
      )

      expect(state.dig("column_widths", "/admin/workers", "worker.interview_summary")).to eq(800.0)
    end

    # 空幅を送ると指定カラムの保存幅が削除され、空scopeも残らないことを確認する
    it "removes a column width when the width is blank" do
      store.update(
        "browser-1",
        {
          "preference" => "column_width",
          "scope" => "/admin/workers",
          "column_id" => "worker.name",
          "width" => "240"
        }
      )

      state = store.update(
        "browser-1",
        {
          "preference" => "column_width",
          "scope" => "/admin/workers",
          "column_id" => "worker.name",
          "width" => ""
        }
      )

      expect(state["column_widths"]).to eq({})
    end

    # 想定外の設定名はRedisへ保存せずエラーにすることを確認する
    it "rejects unknown preference names" do
      expect do
        store.update("browser-1", { "preference" => "unknown", "width" => "100" })
      end.to raise_error(described_class::InvalidPreference, "unknown preference")
    end

    # scopeやcolumn_idに保存キーとして扱わない文字が含まれる場合はエラーにすることを確認する
    it "rejects invalid column identifiers" do
      expect do
        store.update(
          "browser-1",
          {
            "preference" => "column_width",
            "scope" => "/admin/workers?<script>",
            "column_id" => "worker.name",
            "width" => "100"
          }
        )
      end.to raise_error(described_class::InvalidPreference, "scope is invalid")
    end
  end
end
