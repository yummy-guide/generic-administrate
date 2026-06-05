# frozen_string_literal: true

RSpec.describe "column resizer assets" do
  let(:javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/column_resizer.js", __dir__))
  end

  let(:stylesheet_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/_column_resizer.scss", __dir__))
  end

  let(:sticky_table_headers_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/sticky_table_headers.js", __dir__))
  end

  let(:sticky_left_columns_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/sticky_left_columns.js", __dir__))
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

  # 幅適用後の固定ヘッダー追従が全体rebuildではなく対象カラム同期を優先することを静的に確認する
  it "uses targeted fixed header synchronization after applying a width" do
    expect(javascript_source).to include("window.YummyGuideAdministrateStickyTableHeaders")
    expect(javascript_source).to include("api.refreshColumnWidth({")
    expect(sticky_table_headers_source).to include("window.YummyGuideAdministrateStickyTableHeaders = {")
    expect(sticky_table_headers_source).to include("refreshColumnWidth: refreshColumnWidth")
    expect(sticky_table_headers_source).to include("refreshTable: refreshTable")
    expect(sticky_table_headers_source).to include("function refreshColumnWidth(options)")
    expect(sticky_table_headers_source).to include("applySourceColumnMinWidth(sourceTable, columnIndex, columnCount, width)")
    expect(sticky_table_headers_source).to include("applyFixedHeaderCellWidth(fixedTable, columnIndex, width)")
    expect(sticky_table_headers_source).to include("suppressResizeBuild(scroll)")
  end

  # 幅適用後の固定左列追従もResizeObserverの重複再計算に頼らないことを静的に確認する
  it "refreshes sticky left columns directly after applying a width" do
    expect(javascript_source).to include("window.YummyGuideAdministrateStickyLeftColumns")
    expect(javascript_source).to include("api.refreshColumnWidth({")
    expect(javascript_source).to include("sourceTable: pendingWidth.sourceTable")
    expect(javascript_source).to include("columnId: pendingWidth.columnId")
    expect(javascript_source).to include("width: pendingWidth.width")
    expect(javascript_source).to include("api.refreshTable(sourceTable)")
    expect(javascript_source).to include("refreshStickyLeftColumns(pendingWidth.sourceTable)")
    expect(sticky_left_columns_source).to include("window.YummyGuideAdministrateStickyLeftColumns = {")
    expect(sticky_left_columns_source).to include("refreshColumnWidth: refreshColumnWidth")
    expect(sticky_left_columns_source).to include("refreshTable: refreshTable")
    expect(sticky_left_columns_source).to include("function refreshTable(table)")
    expect(sticky_left_columns_source).to include("function refreshColumnWidth(options)")
    expect(sticky_left_columns_source).to include("suppressResizeApply(table)")
  end

  # 固定5列の4列目を調整した直後に5列目のleftが古い幅で残らないことを静的に確認する
  it "uses the resized fixed column width when recalculating sticky-left offsets" do
    expect(sticky_left_columns_source).to include("function widthOverride(headerCells, options)")
    expect(sticky_left_columns_source).to include("columnIndex(headerCells, settings.columnId)")
    expect(sticky_left_columns_source).to include("width: preciseNumber(width)")
    expect(sticky_left_columns_source).to include("var hasMeasuredWidth = widths.some(Boolean)")
    expect(sticky_left_columns_source).to include("applyWidthOverride(widths, override)")
    expect(sticky_left_columns_source).to include("var offsets = stickyOffsets(table, count, options)")
  end

  # 幅リセット時は明示幅がないため、クリア後に通常の固定左列再計算へ戻すことを静的に確認する
  it "recalculates sticky-left offsets after clearing a column width" do
    expect(javascript_source).to include("clearColumnWidth(columnId, key)")
    expect(javascript_source).to include("refreshStickyHeaderTable(sourceTable, function()")
    expect(javascript_source).to include("refreshStickyLeftColumns(sourceTable)")
  end

  # ダブルクリックで幅リセットした時も、固定列同期が完了するまで待機カーソルを表示することを静的に確認する
  it "shows a wait cursor while resetting a column width" do
    expect(javascript_source).to include("clearColumnWidth(columnId, key)")
    expect(javascript_source).to include("startApplyingWidth()")
    expect(javascript_source).to include("stopApplyingWidth(null)")
    expect(javascript_source).to include("scheduleStickyRefresh(function()")
  end

  # 幅リセット時は固定ヘッダーの管理幅を先に作り直してから固定左列を再計算することを静的に確認する
  it "rebuilds fixed headers before refreshing sticky-left columns after clearing a width" do
    expect(javascript_source).to include("function refreshStickyHeaderTable(sourceTable, callback)")
    expect(javascript_source).to include("api.refreshTable(sourceTable, callback)")
    expect(javascript_source).to include("scheduleStickyRefresh(callback)")
    expect(sticky_table_headers_source).to include("function refreshTable(sourceTable, callback)")
    expect(sticky_table_headers_source).to include("initializeFixedHeaderForScroll(scroll)")
    expect(sticky_table_headers_source).to include("window.requestAnimationFrame(callback)")
  end
end
