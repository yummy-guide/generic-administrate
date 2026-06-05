# frozen_string_literal: true

RSpec.describe "column resizer assets" do
  let(:javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/column_resizer.js", __dir__))
  end

  let(:stylesheet_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/_column_resizer.scss", __dir__))
  end

  # 未調整列は内容幅で表示され、調整済み列だけが幅固定されることを静的に確認する
  it "scopes fixed width rules to adjusted columns" do
    expect(javascript_source).to include("data-admin-column-resizer-adjusted-columns")
    expect(javascript_source).to include("setAdjustedColumn(table, index, true)")
    expect(javascript_source).to include("setAdjustedColumn(table, index, false)")
    expect(javascript_source).to include("ADJUSTED_COLUMNS_ATTRIBUTE + '~=\"' + nthChild")
  end

  # 幅調整後の内容が常に折り返されるCSSが生成されることを確認する
  it "generates wrapping rules for adjusted columns" do
    expect(javascript_source).to include("white-space: normal !important")
    expect(javascript_source).to include("overflow-wrap: anywhere !important")
    expect(javascript_source).to include("word-break: break-word !important")
  end

  # デフォルト状態の列幅が内容の最大幅を基準に決まることを確認する
  it "uses max-content table sizing by default" do
    expect(stylesheet_source).to include("table-layout: auto !important")
    expect(stylesheet_source).to include("width: max-content !important")
    expect(stylesheet_source).to include("min-width: 100% !important")
  end

  # ドラッグ中に固定ヘッダー同期を繰り返さず、調整完了後だけ同期することを静的に確認する
  it "synchronizes fixed headers after drag completion instead of during drag" do
    expect(javascript_source).not_to include("scheduleStickyRefresh(false)")
    expect(javascript_source).not_to include("refreshDuringDrag")
    expect(javascript_source).not_to include("columnNeedsDragRefresh")
    expect(javascript_source).not_to include("STICKY_REFRESH_INTERVAL")
    expect(javascript_source).to include("scheduleStickyRefresh(function()")
    expect(javascript_source.scan(/scheduleStickyRefresh\(/).size).to eq(3)
  end

  # ドラッグ中は実テーブルを再レイアウトせず、プレビューだけを更新することを静的に確認する
  it "updates only the lightweight preview while dragging" do
    expect(javascript_source).to include("createDragPreview(sourceTable, previewHeader, startWidth)")
    expect(javascript_source).to include("updateDragPreview(dragState.preview, dragState.currentWidth)")
    expect(javascript_source).to include("schedulePendingWidthApply(pendingWidth)")
    expect(javascript_source).to include("applyColumnWidth(pendingWidth.columnId, pendingWidth.width, pendingWidth.storageKey)")
    expect(javascript_source).not_to include("applyColumnWidth(dragState.columnId, dragState.currentWidth")
  end

  # ドラッグ中の調整後幅を半透明カラムで表示するCSSがあることを確認する
  it "defines a translucent column preview" do
    expect(stylesheet_source).to include(".admin-column-resizer__preview")
    expect(stylesheet_source).to include(".admin-column-resizer__preview-label")
    expect(stylesheet_source).to include("pointer-events: none")
    expect(stylesheet_source).to include("will-change: width")
  end

  # 幅の適用中だけ待機カーソルを表示することを静的に確認する
  it "shows a wait cursor while applying the final width" do
    expect(javascript_source).to include("APPLYING_BODY_CLASS = 'admin-column-resizer--applying'")
    expect(javascript_source).to include("document.body.classList.add(APPLYING_BODY_CLASS)")
    expect(javascript_source).to include("document.body.classList.remove(APPLYING_BODY_CLASS)")
    expect(stylesheet_source).to include(".admin-column-resizer--applying")
    expect(stylesheet_source).to include("cursor: wait !important")
  end
end
