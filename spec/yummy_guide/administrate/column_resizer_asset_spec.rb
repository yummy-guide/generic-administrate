# frozen_string_literal: true

RSpec.describe "column resizer assets" do
  let(:javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/column_resizer.js", __dir__))
  end

  let(:stylesheet_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/_column_resizer.scss", __dir__))
  end

  let(:components_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/components.scss", __dir__))
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
    expect(javascript_source).to include("refreshStickyHeaderColumn(pendingWidth, function()")
    expect(javascript_source).to include("scheduleStickyRefresh(callback)")
  end

  # ドラッグ中は実テーブルを再レイアウトせず、プレビューだけを更新することを静的に確認する
  it "updates only the lightweight preview while dragging" do
    expect(javascript_source).to include("createDragPreview(sourceTable, previewHeader, startWidth)")
    expect(javascript_source).to include("updateDragPreview(dragState.preview, dragState.currentWidth)")
    expect(javascript_source).to include("schedulePendingWidthApply(pendingWidth)")
    expect(javascript_source).to include("applyColumnWidth(pendingWidth.columnId, pendingWidth.width, pendingWidth.storageKey)")
    expect(javascript_source).to include("sourceTable: dragState.sourceTable")
    expect(javascript_source).not_to include("applyColumnWidth(dragState.columnId, dragState.currentWidth")
  end

  # ハンドルのクリックやダブルクリックで、ドラッグ完了扱いの幅適用が予約されないことを静的に確認する
  it "does not apply a width when the pointer did not move" do
    expect(javascript_source).to include("var shouldApplyWidth = dragState.moved && !pointerCancelled")
    expect(javascript_source).to include("stopDragging(!shouldApplyWidth)")
    expect(javascript_source).to include("if (!shouldApplyWidth) return")
  end

  # ダブルクリックの幅リセット前に、未実行の幅適用予約とプレビューを破棄することを静的に確認する
  it "cancels pending width application before resetting a column" do
    expect(javascript_source).to include("function cancelPendingWidthApply()")
    expect(javascript_source).to include("window.cancelAnimationFrame(widthApplyFrame)")
    expect(javascript_source).to include("removePreview(pendingWidthApply.preview)")
    expect(javascript_source).to include("pendingWidthApply = null")
    expect(javascript_source).to include("cancelPendingWidthApply()")
  end

  # ドラッグ中の調整後幅を半透明カラムで表示するCSSがあることを確認する
  it "defines a translucent column preview" do
    expect(stylesheet_source).to include(".admin-column-resizer__preview")
    expect(stylesheet_source).to include("pointer-events: none")
    expect(stylesheet_source).to include("will-change: width")
  end

  # 幅調整中のpxラベルが表示されないことを静的に確認する
  it "does not render a pixel width label in the preview" do
    expect(javascript_source).not_to include("PREVIEW_LABEL_CLASS")
    expect(javascript_source).not_to include("admin-column-resizer__preview-label")
    expect(javascript_source).not_to include("Math.round(width) + 'px'")
    expect(stylesheet_source).not_to include(".admin-column-resizer__preview-label")
  end

  # 固定列ヘッダーより幅調整ハンドルを背面にすることを静的に確認する
  it "keeps resize handles behind sticky column headers" do
    expect(stylesheet_source).to include("z-index: 1")
    expect(stylesheet_source).not_to include("z-index: 20")
  end

  # 幅の適用中だけ待機カーソルを表示することを静的に確認する
  it "shows a wait cursor while applying the final width" do
    expect(javascript_source).to include("APPLYING_BODY_CLASS = 'admin-column-resizer--applying'")
    expect(javascript_source).to include("function startApplyingWidth()")
    expect(javascript_source).to include("document.body.classList.add(APPLYING_BODY_CLASS)")
    expect(javascript_source).to include("document.body.classList.remove(APPLYING_BODY_CLASS)")
    expect(stylesheet_source).to include(".admin-column-resizer--applying")
    expect(stylesheet_source).to include("cursor: wait !important")
  end

  # モバイルのtouch/pen操作でハンドル外へ移動しても調整を継続できることを静的に確認する
  it "supports touch and pen pointer dragging on mobile" do
    expect(javascript_source).to include("event.pointerType !== 'mouse' || event.button === 0")
    expect(javascript_source).to include("event.isPrimary === false")
    expect(javascript_source).to include("handle.setPointerCapture(event.pointerId)")
    expect(javascript_source).to include("dragState.handle.releasePointerCapture(dragState.pointerId)")
    expect(stylesheet_source).to include("right: -14px")
    expect(stylesheet_source).to include("width: 36px")
  end

  # CSSだけで固定ヘッダーと固定左列の初期表示に必要なスタイルがあることを静的に確認する
  it "defines CSS-only sticky table styles" do
    expect(components_source).to include("[data-css-sticky-table]")
    expect(components_source).to include("max-height: var(--admin-sticky-table-max-height")
    expect(components_source).to include("top: 0")
    expect(components_source).to include("--sticky-col-1-width")
    expect(components_source).to include("left: var(--sticky-left, 0)")
    expect(components_source).to include("left: var(--sticky-mobile-left, 0)")
    expect(components_source).to include(":not(.sticky-left)")
    expect(components_source).to include(":not(.sticky-left-mobile)")
    expect(components_source).to include("th.sticky.actions-column")
    expect(components_source).to include("td.sticky.actions-column")
    expect(components_source).to include(".scroll-table[data-css-sticky-table] table > thead th")
    expect(components_source).to include(".scroll-table[data-css-sticky-table] table[data-fixed-columns-count] > thead th")
    expect(components_source).to include(".scroll-table[data-css-sticky-table] table[data-mobile-fixed-columns-count] th.sticky-left-mobile")
    expect(components_source).to include(".home-table__wrapper[data-css-sticky-table] table[data-mobile-fixed-columns-count] td.sticky-left-mobile")
    expect(components_source).to include("@media (max-width: 767px)")
    expect(components_source).to include(".scroll-table table th.sticky.actions-column")
    expect(components_source).to include("right: auto")
    expect(components_source).to include("position: static")
    expect(components_source).to include("background-color: #121012")
    expect(components_source).to include("color: #fff")
    expect(components_source).to include(".scroll-table[data-css-sticky-table] table > thead th a")
    expect(components_source).to include("color: inherit")
    expect(components_source).to include("z-index: 6")
  end

  # 固定列リサイズ後にCSS変数のleftと幅を再計算する処理があることを静的に確認する
  it "recalculates CSS sticky-left offsets after applying column widths" do
    expect(javascript_source).to include("function refreshCssStickyLeftColumns(table)")
    expect(javascript_source).to include("refreshCssStickyLeftColumnSet(table, 'sticky-left', '--sticky-left', '--sticky-width')")
    expect(javascript_source).to include("refreshCssStickyLeftColumnSet(table, 'sticky-left-mobile', '--sticky-mobile-left', '--sticky-mobile-width')")
    expect(javascript_source).to include("cell.style.setProperty(leftVariable, cssPixelValue(left))")
    expect(javascript_source).to include("refreshCssStickyLeftColumns(table)")
  end

  # 固定ヘッダー複製APIがなくても幅適用後の完了処理に進めることを静的に確認する
  it "keeps a resize fallback when fixed header JavaScript is absent" do
    expect(javascript_source).to include("var api = window.YummyGuideAdministrateStickyTableHeaders")
    expect(javascript_source).to include("if (api && typeof api.refreshColumnWidth === 'function')")
    expect(javascript_source).to include("scheduleStickyRefresh(callback)")
  end

  # 幅リセット時も固定列のCSS変数を再計算することを静的に確認する
  it "recalculates CSS sticky-left offsets after clearing a column width" do
    expect(javascript_source).to include("clearColumnWidth(columnId, key)")
    expect(javascript_source).to include("clearTableColumnWidth(table, columnId)")
    expect(javascript_source).to include("refreshCssStickyLeftColumns(table)")
  end
end
