# frozen_string_literal: true

RSpec.describe "copy cell assets" do
  let(:components_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/components.scss", __dir__))
  end

  # コピー用ボタンとアイコンをCSSで強制的に隠さないことを静的に確認する
  it "does not force-hide the copy cell button or icon" do
    expect(components_source.scan(/\.admin-copy-cell__(?:button|icon)[^{]*\{[^}]*display:\s*none\s*!important/m)).to be_empty
    expect(components_source).to include(".admin-copy-cell__icon {\n  display: inline-flex;")
    expect(components_source).to include('mask: image-url("yummy_guide_administrate/icon-copy.svg") center / contain no-repeat;')
  end

  # テーブルセルではホバーやフォーカス時にコピー操作が表示されることを静的に確認する
  it "reveals copy cell controls on hover or focus" do
    expect(components_source).to include("td.cell-data:hover .admin-copy-cell__button:not([disabled])")
    expect(components_source).to include(".admin-copy-cell:focus-within .admin-copy-cell__link")
    expect(components_source).to include(".admin-copy-cell__button:focus-visible")
    expect(components_source).to include("opacity: 1;")
  end

  # 詳細画面ではコピー操作が常時表示される指定を維持することを静的に確認する
  it "keeps attribute copy controls visible" do
    expect(components_source).to match(/\.attribute-data \.admin-copy-cell__link,\s*\.attribute-data \.admin-copy-cell__button:not\(\[disabled\]\) \{\s*opacity: 1;/m)
  end

  # フィルター操作アイコンをGem内のSVG assetからCSS maskで描画することを静的に確認する
  it "uses bundled SVG assets for filter control icons" do
    expect(components_source).to include('mask: image-url("yummy_guide_administrate/icon-eraser.svg") center / contain no-repeat;')
    expect(components_source).to include('mask: image-url("yummy_guide_administrate/icon-check-square.svg") center / contain no-repeat;')
  end

  # フィルター操作ボタンのセルが項目内で上下中央に配置されることを静的に確認する
  it "keeps filter control cells vertically centered" do
    expect(components_source).to include(".filter-form .filter_table td.filter-table__clear,\n.yummy-guide-administrate-filter-form .filter_table td.filter-table__clear {\n  vertical-align: middle;")
    expect(components_source).to include(".filter-checkbox-group__actions.filter-checkbox-group__actions--clear-cell {\n  flex-direction: column;\n  flex-wrap: nowrap;")
  end

  # フィルターの項目名・入力フォーム・操作ボタンの列間を4pxに保ち、項目名を折り返せることを静的に確認する
  it "keeps filter table columns spaced and labels wrappable" do
    expect(components_source.scan(/border-spacing: 4px 0;/).size).to be >= 2
    expect(components_source.scan(/overflow-wrap: anywhere;/).size).to be >= 2
    expect(components_source).to include(".filter-table__clear {\n  width: 1%;\n  padding-left: 0;")
  end
end
