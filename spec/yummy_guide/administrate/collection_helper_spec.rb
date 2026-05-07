# frozen_string_literal: true

require "spec_helper"

RSpec.describe YummyGuide::Administrate::CollectionHelper do
  subject(:helper_host) do
    Class.new do
      include ActionView::Context
      include ActionView::Helpers::CaptureHelper
      include ActionView::Helpers::FormTagHelper
      include ActionView::Helpers::OutputSafetyHelper
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::UrlHelper
      include ERB::Util
      include YummyGuide::Administrate::CollectionHelper

      def url_for(options = nil)
        options
      end
    end.new
  end

  describe "#yummy_guide_administrate_collection_table_fixed_columns_count" do
    # dashboard の固定列数が表示列数を超えていても、実際の列数で打ち止めになることを確認する
    it "caps the fixed column count by the number of visible attributes" do
      dashboard_class = Class.new do
        def self.index_fixed_columns_count
          4
        end
      end

      page = Object.new
      page.instance_variable_set(:@dashboard, dashboard_class.new)
      collection_presenter = Struct.new(:attribute_types).new({ id: :integer, name: :string })

      expect(helper_host.yummy_guide_administrate_collection_table_fixed_columns_count(page: page, collection_presenter: collection_presenter)).to eq(2)
    end
  end

  describe "#yummy_guide_administrate_build_collection_cell" do
    let(:present_path) { "/admin/articles/test-article" }

    # 明示的に保持指定したリンクは残しつつ、コピー操作を追加できることを確認する
    it "preserves explicitly marked links and renders a copy button for the cell text" do
      content = helper_host.link_to(
        "Page",
        "/areas/japan/nagano/matsumoto/articles/test-article",
        class: "button button__public",
        data: { behavior: "preserve-collection-link" }
      )

      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: content, present_path: present_path)

      expect(cell[:linkable]).to be(false)
      expect(cell[:content]).to include('href="/areas/japan/nagano/matsumoto/articles/test-article"')
      expect(cell[:content]).to include('data-behavior="copy-cell"')
      expect(cell[:content]).to include('data-copy-text="Page"')
    end

    # 参照リンク指定時は詳細遷移アイコンがコピー操作の前に並ぶことを確認する
    it "renders a reference icon before the copy button when requested" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(
        content: "Writer Name",
        present_path: present_path,
        reference_link: true
      )

      expect(cell[:content]).to include('class="admin-copy-cell__link"')
      expect(cell[:content]).to include(%(href="#{present_path}"))
      expect(cell[:content]).to include('class="admin-copy-cell__actions"')
      expect(cell[:content]).to match(/admin-copy-cell__link.*admin-copy-cell__button/m)
    end

    # 先頭アクションを指定した場合はコピー操作より前に表示されることを確認する
    it "renders leading actions before the copy button" do
      edit_button = helper_host.button_tag("Edit", type: "button", class: "owner-memo-cell__edit")

      cell = helper_host.yummy_guide_administrate_build_collection_cell(
        content: "Owner memo",
        present_path: present_path,
        leading_actions: edit_button
      )

      expect(cell[:content]).to match(/owner-memo-cell__edit.*admin-copy-cell__button/m)
    end

    # button などの操作要素はコピー対象の文字列から除外されることを確認する
    it "omits interactive child text from copied content" do
      content = helper_host.content_tag(:div) do
        helper_host.safe_join([
          helper_host.content_tag(:span, "Memo"),
          helper_host.button_tag("Edit", type: "button")
        ])
      end

      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: content, present_path: present_path)

      expect(cell[:content]).to include('data-copy-text="Memo"')
      expect(cell[:content]).to include(">Edit</button>")
    end

    # 複数行コンテンツは改行を維持したままコピー文字列へ変換されることを確認する
    it "preserves line breaks when copying multiline content" do
      content = helper_host.content_tag(:div) do
        helper_host.safe_join([
          helper_host.content_tag(:div, "first line"),
          helper_host.tag.br,
          helper_host.content_tag(:div, "second line")
        ])
      end

      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: content, present_path: present_path)

      expect(cell[:content]).to include("data-copy-text=\"first line\nsecond line\"")
    end

    # copy_text_transform を渡した場合はコピー用文字列にだけ変換が適用されることを確認する
    it "applies a copy text transform when provided" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(
        content: "Walter Reßel",
        present_path: present_path,
        copy_text_transform: ->(text) { helper_host.yummy_guide_administrate_safe_transliterate_copy_text(text) }
      )

      expect(cell[:content]).to include('data-copy-text="Walter Ressel"')
      expect(cell[:content]).to include("Walter Reßel")
    end

    # 文字化けする transliterate 結果は採用せず元の値を残すことを確認する
    it "falls back to the original text when transliteration would add question marks" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(
        content: "山田太郎",
        present_path: present_path,
        copy_text_transform: ->(text) { helper_host.yummy_guide_administrate_safe_transliterate_copy_text(text) }
      )

      expect(cell[:content]).to include('data-copy-text="山田太郎"')
    end

    # コピー対象が空ならコピー用ボタンを出さないことを確認する
    it "does not render a copy button for blank text" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: "", present_path: present_path)

      expect(cell[:content]).not_to include('data-behavior="copy-cell"')
      expect(cell[:content]).not_to include("admin-copy-cell__button")
    end

    # 参照リンク指定がない場合は参照アイコンを描画しないことを確認する
    it "does not render a reference icon without an explicit request" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: "Writer Name", present_path: present_path)

      expect(cell[:content]).not_to include("admin-copy-cell__link")
    end

    # 明示指定した copy_text を優先してコピー対象に使うことを確認する
    it "uses explicit copy text when provided" do
      cell = helper_host.yummy_guide_administrate_build_collection_cell(
        content: "<strong>Visible Value</strong>".html_safe,
        present_path: present_path,
        copy_text: "Copied Value"
      )

      expect(cell[:content]).to include('data-copy-text="Copied Value"')
      expect(cell[:content]).to include("<strong>Visible Value</strong>")
    end

    # 通常の a タグは一度テキストへ戻してから copy frame を組み立てることを確認する
    it "strips ordinary links before rendering the copy button" do
      content = helper_host.link_to("Example", "/external")

      cell = helper_host.yummy_guide_administrate_build_collection_cell(content: content, present_path: present_path)

      expect(cell[:linkable]).to be(false)
      expect(cell[:content]).not_to include('href="/external"')
      expect(cell[:content]).to include("Example")
    end
  end
end
