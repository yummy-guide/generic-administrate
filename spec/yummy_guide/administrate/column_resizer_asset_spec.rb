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

  let(:resizable_navigation_source) do
    File.read(File.expand_path("../../../app/assets/stylesheets/yummy_guide_administrate/_resizable_navigation.scss", __dir__))
  end

  let(:resizable_navigation_javascript_source) do
    File.read(File.expand_path("../../../app/assets/javascripts/yummy_guide_administrate/resizable_navigation.js", __dir__))
  end

  # 未調整列は内容幅で表示され、調整済み列だけが幅固定されることを静的に確認する
  it "scopes fixed width rules to adjusted columns" do
    expect(javascript_source).to include("data-admin-column-resizer-adjusted-columns")
    expect(javascript_source).to include("setAdjustedColumn(table, index, true)")
    expect(javascript_source).to include("setAdjustedColumn(table, index, false)")
    expect(stylesheet_source).to include('[data-admin-column-resizer-adjusted-columns~="#{$index}"]')
    expect(stylesheet_source).to include('[style*="--admin-column-resizer-col-#{$index}:"]')
  end

  # 幅調整後の内容が常に折り返される静的CSSがあることを確認する
  it "defines wrapping rules for adjusted columns" do
    expect(stylesheet_source).to include("white-space: normal !important")
    expect(stylesheet_source).to include("overflow-wrap: anywhere !important")
    expect(stylesheet_source).to include("word-break: break-word !important")
  end

  # デフォルト状態の列幅が内容の最大幅を基準に決まることを確認する
  it "uses max-content table sizing by default" do
    expect(stylesheet_source).to include("table[data-fixed-columns-count]")
    expect(stylesheet_source).to include("table-layout: auto !important")
    expect(stylesheet_source).to include("width: max-content !important")
    expect(stylesheet_source).to include("min-width: 100% !important")
  end

  # 固定ヘッダー複製用の同期処理を持たず、元テーブルの固定左列だけ再計算することを静的に確認する
  it "does not depend on duplicated fixed header synchronization" do
    expect(javascript_source).not_to include("YummyGuideAdministrateStickyTableHeaders")
    expect(javascript_source).not_to include("scheduleStickyRefresh")
    expect(javascript_source).not_to include("table-fixed-header__table")
    expect(javascript_source).to include("refreshTableWidthLayout(table, {")
    expect(javascript_source).not_to include("refreshStickyLeftColumnsForWidth")
  end

  # ドラッグ中は実テーブルを再レイアウトせず、プレビューだけを更新することを静的に確認する
  it "updates only the lightweight preview while dragging" do
    expect(javascript_source).to include("createDragPreview(sourceTable, previewHeader, startWidth, previewHeaderRect)")
    expect(javascript_source).to include("updateDragPreview(dragState.preview, dragState.currentWidth)")
    expect(javascript_source).to include("schedulePendingWidthApply(pendingWidth)")
    expect(javascript_source).to include("applyColumnWidth(pendingWidth.columnId, pendingWidth.width, pendingWidth.storageScope)")
    expect(javascript_source).to include("sourceTable: dragState.sourceTable")
    expect(javascript_source).not_to include("applyColumnWidth(dragState.columnId, dragState.currentWidth")
  end

  # プレビュー表示はブラウザの現在表示範囲へ収め、実際の適用幅は維持することを静的に確認する
  it "clips the drag preview to the visible viewport width" do
    expect(javascript_source).to include("function viewportWidth()")
    expect(javascript_source).to include("var viewportRight = viewportWidth()")
    expect(javascript_source).to include("var left = Math.max(0, Math.min(headerRect.left, viewportRight))")
    expect(javascript_source).to include("height: Math.max(32, viewportBottom - top)")
    expect(javascript_source).to include("hiddenLeft: Math.max(0, left - headerRect.left)")
    expect(javascript_source).to include("maxWidth: Math.max(0, viewportRight - left)")
    expect(javascript_source).to include("var visibleWidth = Math.max(0, width - preview.hiddenLeft)")
    expect(javascript_source).to include("Math.min(visibleWidth, preview.maxWidth)")
    expect(javascript_source).to include("width: Math.max(MIN_WIDTH, dragState.currentWidth || dragState.startWidth)")
  end

  # プレビューはヘッダー矩形とviewportだけで表示し、重いテーブル範囲計測を使わないことを静的に確認する
  it "shows the drag preview without measuring the full table bounds" do
    expect(javascript_source).to include("function previewBoundsFromHeader(headerRect)")
    expect(javascript_source).to include("var bounds = previewBoundsFromHeader(resolvedHeaderRect)")
    expect(javascript_source).to include("applyDragPreviewBounds(preview, bounds)")
    expect(javascript_source).to include("previewParentForTable(table).appendChild(element)")
    expect(javascript_source).not_to include("function previewBoundsForTable")
    expect(javascript_source).not_to include("scheduleDragPreviewBoundsRefresh")
    expect(javascript_source).not_to include("boundsFrame")
    expect(javascript_source).not_to include("var tableRect = table.getBoundingClientRect()")
    expect(javascript_source).not_to include("scrollContainer.getBoundingClientRect()")
  end

  # ドラッグ開始時はヘッダー矩形と幅の計測結果を再利用し、プレビュー表示までの同期計測を減らすことを静的に確認する
  it "reuses resize handle measurements when starting a drag" do
    expect(javascript_source).to include("headers: headers")
    expect(javascript_source).to include("return state.headers[index] || null")
    expect(javascript_source).to include("function resizeTargetFromEvent(event)")
    expect(javascript_source).to include("var handleRect = target.rect")
    expect(javascript_source).to include("var handleHeaderWidth = preciseNumber(handleRect.width || header.offsetWidth || 0)")
    expect(javascript_source).to include("var sourceHeaderWidth = sourceHeader === header ? handleHeaderWidth : measuredWidth(sourceHeader)")
    expect(javascript_source).to include("var previewHeaderRect = previewHeader === header ? handleRect : null")
  end

  # 幅確定時は待ち時間を増やさず、1回のrequestAnimationFrameで適用することを静的に確認する
  it "applies the pending width on the next animation frame" do
    expect(javascript_source).to include("function schedulePendingWidthApply(pendingWidth)")
    expect(javascript_source).to include("widthApplyFrame = window.requestAnimationFrame(function()")
    expect(javascript_source).to include("widthApplyFrame = null")
    expect(javascript_source).to include("applyPendingWidth(pendingWidth)")
    expect(javascript_source).not_to match(/widthApplyFrame = window\.requestAnimationFrame\(function\(\) \{[\s\S]*?widthApplyFrame = window\.requestAnimationFrame/)
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

  # ドラッグ開始時に解決済みヘッダーから対象テーブルを取得し、未定義変数で停止しないことを静的に確認する
  it "uses the resolved header when starting a column drag" do
    expect(javascript_source).to include("var sourceTable = sourceTableForHandle(header)")
    expect(javascript_source).not_to include("var sourceTable = sourceTableForHandle(handle)")
  end

  # CSSだけで固定ヘッダーと固定左列の初期表示に必要なスタイルがあることを静的に確認する
  it "defines CSS-only sticky table styles" do
    expect(components_source).to include("[data-css-sticky-table]")
    expect(components_source).not_to include("admin-sticky-table-max-height")
    expect(components_source).to include("max-height: none")
    expect(components_source).to include("overflow: visible")
    expect(components_source).to include(".scroll-table:not([data-css-sticky-table])")
    expect(components_source).to include("--admin-main-left-offset")
    expect(components_source).to include("--admin-sticky-table-header-top")
    expect(components_source).to include("position: fixed")
    expect(components_source).to include("top: var(--admin-sticky-page-header-top)")
    expect(components_source).to include("inline-size: 100vw !important")
    expect(components_source).to include("width: 100vw !important")
    expect(components_source).to include("right: auto !important")
    expect(components_source).to include("padding-top: var(--admin-sticky-page-header-height) !important")
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
    expect(components_source).to include("th.sticky-left:not(.sticky-left-mobile)")
    expect(components_source).to include("td.sticky-left:not(.sticky-left-mobile)")
    expect(components_source).to include("left: auto !important")
    expect(components_source).to include("position: static !important")
    expect(components_source).to include('table[data-mobile-fixed-columns-count="1"] th.sticky-left-mobile')
    expect(components_source).to include("position: sticky !important")
    expect(components_source).to include("min-inline-size: 0 !important")
    expect(components_source).to include("width: max-content")
    expect(components_source).to include("@media (max-width: 767px)")
    expect(components_source).to include(".scroll-table table th.sticky.actions-column")
    expect(components_source).to include("right: auto")
    expect(components_source).to include("position: static")
    expect(components_source).to include("background-color: #121012")
    expect(components_source).to include("color: #fff")
    expect(components_source).to include(".scroll-table[data-css-sticky-table] table > thead th a")
    expect(components_source).to include("color: inherit")
    expect(components_source).to include("z-index: 7")
    expect(components_source).to include("top: var(--admin-sticky-table-header-top, 0)")
    expect(components_source).to include("--admin-sticky-table-left-offset: var(--admin-sticky-page-header-left, 0px)")
    expect(components_source).to include("--admin-sticky-actions-right: var(--admin-layout-inline-padding)")
    expect(components_source).to include("--admin-sticky-actions-mask-z-index: 6")
    expect(components_source).to include("right: var(--admin-sticky-actions-right, 0px)")
    expect(components_source).to include(".scroll-table table th.sticky.actions-column::after")
    expect(components_source).to include("right: calc(0px - var(--admin-sticky-actions-right, 0px))")
    expect(components_source).to include("width: var(--admin-sticky-actions-right, 0px)")
  end

  # PC表示ではsticky tableをページ全体スクロールで扱うことを静的に確認する
  it "expands the main content to the sticky table width on desktop" do
    expect(components_source).to include("@media screen and (min-width: 768px)")
    expect(components_source).to include("inline-size: max-content !important")
    expect(components_source).to include("max-inline-size: none !important")
    expect(components_source).to include("flex-basis: max-content !important")
  end

  # PC表示ではactions列より右側に固定マスクを置き、テーブル要素が右余白へ見えないことを静的に確認する
  it "masks the desktop page area to the right of the actions column" do
    expect(components_source).to include(".app-container > .main-content:has(> .main-content__body--flush [data-css-sticky-table])::after")
    expect(components_source).to include("body.admin-body > main.main-content:has(> [data-reservations-sticky-body] [data-css-sticky-table])::after")
    expect(components_source).to match(/\.app-container > \.main-content:has\(> \.main-content__body--flush \[data-css-sticky-table\]\)::after,[\s\S]*?position: fixed;/)
    expect(components_source).to match(/\.app-container > \.main-content:has\(> \.main-content__body--flush \[data-css-sticky-table\]\)::after,[\s\S]*?width: var\(--admin-sticky-actions-right, 0px\);/)
    expect(components_source).to match(/\.app-container > \.main-content:has\(> \.main-content__body--flush \[data-css-sticky-table\]\)::after,[\s\S]*?pointer-events: none;/)
    expect(components_source).to match(/\.app-container > \.main-content:has\(> \.main-content__body--flush \[data-css-sticky-table\]\)::after,[\s\S]*?z-index: var\(--admin-sticky-actions-mask-z-index, 6\);/)
  end

  # モバイル表示ではsticky tableをテーブル領域スクロールで扱うことを静的に確認する
  it "keeps sticky tables scrollable inside the table area on mobile" do
    expect(components_source).to include("@media screen and (max-width: 767px)")
    expect(components_source).to include("body :is(.scroll-table, .sticky-table-scroll, .home-table__wrapper, .table-wrap, .af__table__content)[data-css-sticky-table]")
    expect(components_source).to include("overflow: auto !important")
  end

  # sticky table内のactions列はページ右paddingに揃えつつ、左端の疑似境界線を出さないことを静的に確認する
  it "keeps sticky table actions columns aligned without a left divider gap" do
    expect(components_source).to match(/\.scroll-table\[data-css-sticky-table\] table th\.sticky\.actions-column,[\s\S]*?right: var\(--admin-sticky-actions-right, 0px\);/)
    expect(components_source).to match(/\.scroll-table\[data-css-sticky-table\] table td\.sticky\.actions-column,[\s\S]*?right: var\(--admin-sticky-actions-right, 0px\);/)
    expect(components_source).to match(/\.scroll-table\[data-css-sticky-table\] table th\.sticky\.actions-column::before,[\s\S]*?content: none;/)
  end

  # 固定左列はPCではページ全体スクロール用offsetを使い、モバイルではoffsetを0にすることを静的に確認する
  it "uses page-scroll sticky-left offsets on desktop and zero offsets on mobile" do
    expect(components_source).to include("--admin-sticky-table-left-offset: var(--admin-sticky-page-header-left, 0px)")
    expect(components_source).to include("--admin-sticky-table-left-offset: 0px")
    expect(components_source).to match(/\.scroll-table\[data-css-sticky-table\] table th\.sticky-left,[\s\S]*?left: calc\(var\(--admin-sticky-table-left-offset, 0px\) \+ var\(--sticky-left, 0px\)\);/)
    expect(components_source).to match(/table\[data-mobile-fixed-columns-count\] td\.sticky-left-mobile,[\s\S]*?left: calc\(var\(--admin-sticky-table-left-offset, 0px\) \+ var\(--sticky-mobile-left, 0px\)\);/)
  end

  # カラム幅調整ハンドルのCSSが固定ヘッダーのposition: stickyを上書きしないことを静的に確認する
  it "does not override sticky header positioning for resize handles" do
    expect(stylesheet_source).not_to match(/th\[data-column-id\][^{]*\{\s*position:\s*relative;/)
    expect(stylesheet_source).not_to match(/th\[data-admin-column-resizer-column-id\][^{]*\{\s*position:\s*relative;/)
    expect(stylesheet_source).to include("th[data-column-id]::before")
    expect(stylesheet_source).to include("th[data-admin-column-resizer-column-id]::before")
  end

  # 固定ページヘッダーの実高さをCSS変数へ反映し、テーブルヘッダー位置を追従させることを静的に確認する
  it "updates sticky table header offset from measured page header height" do
    expect(javascript_source).to include("CSS_STICKY_TABLE_SELECTOR = '[data-css-sticky-table]'")
    expect(javascript_source).to include("STICKY_PAGE_HEADER_HEIGHT_VARIABLE = '--admin-sticky-page-header-height'")
    expect(javascript_source).to include("function measuredStickyPageHeaderHeight(mainContent, header)")
    expect(javascript_source).to include("header.getBoundingClientRect().height")
    expect(javascript_source).to include("header.scrollHeight || 0")
    expect(javascript_source).to include("mainContent.style.setProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE, value)")
    expect(javascript_source).to include("mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE)")
    expect(javascript_source).not_to include("new ResizeObserver(function()")
    expect(javascript_source).to include("refreshStickyHeaderLayoutForTable(table)")
    expect(javascript_source).to include("refreshTableWidthLayout(table")
    expect(javascript_source).not_to include("refreshStickyHeaderLayoutForTable(pendingWidth.sourceTable)")
    expect(javascript_source).to include("refreshStickyHeaderLayout: refreshStickyHeaderLayout")
  end

  # window resize中は再計算を連続実行せず、最後のresizeから0.5秒後に反映することを静的に確認する
  it "debounces sticky header refreshes after window resize" do
    expect(javascript_source).to include("WINDOW_RESIZE_REFRESH_DELAY = 500")
    expect(javascript_source).to include("var resizeRefreshTimer = null")
    expect(javascript_source).to include("function scheduleWindowResizeRefresh()")
    expect(javascript_source).to include("window.clearTimeout(resizeRefreshTimer)")
    expect(javascript_source).to include("window.setTimeout(function()")
    expect(javascript_source).to include("var stickyTableMainContents = new Set()")
    expect(javascript_source).to include("function refreshTrackedStickyHeaderLayout()")
    expect(javascript_source).to include("trackStickyTable(table)")
    expect(javascript_source).to include("refreshTrackedStickyHeaderLayout()")
    expect(javascript_source).to include("}, WINDOW_RESIZE_REFRESH_DELAY)")
    expect(javascript_source).to include("window.addEventListener('resize', scheduleWindowResizeRefresh)")
    expect(javascript_source).not_to include("refreshStickyHeaderLayout(document)")
    expect(javascript_source).not_to include("window.addEventListener('resize', function() {\n    refreshStickyHeaderLayout(document);\n  });")
  end

  # 固定ナビがテーブルより前面の不透明なスクロール領域として表示されることを静的に確認する
  it "keeps fixed navigation above sticky tables with an opaque background" do
    expect(components_source).to include("--admin-page-background: #f6f7f7")
    expect(components_source).to include("--admin-navigation-z-index: 40")
    expect(components_source).to include(".app-container > .navigation")
    expect(components_source).to include(".app-container > .main-content")
    expect(components_source).not_to include("\n  .navigation {\n")
    expect(components_source).not_to include("\n  .main-content {\n")
    expect(components_source).to include("background: var(--admin-page-background, #f6f7f7)")
    expect(components_source).to include("height: calc(100dvh - var(--admin-navigation-top, 0px) - var(--admin-navigation-bottom, 0px))")
    expect(components_source).to include("max-height: calc(100dvh - var(--admin-navigation-top, 0px) - var(--admin-navigation-bottom, 0px))")
    expect(components_source).to include("min-height: 0")
    expect(components_source).to include("overflow-x: hidden")
    expect(components_source).to include("overflow-y: auto")
    expect(components_source).to include("z-index: var(--admin-navigation-z-index, 40)")
    expect(components_source).to include("box-shadow: 0 calc(0px - var(--admin-sticky-page-header-top, 0px)) 0 var(--admin-sticky-page-header-top, 0px) var(--admin-page-background, #f6f7f7)")
    expect(resizable_navigation_source).to include("background: var(--admin-page-background, #f6f7f7)")
    expect(resizable_navigation_source).to include("background: inherit")
    expect(resizable_navigation_source).to include("display: flex")
    expect(resizable_navigation_source).to include("flex: 1 1 auto")
    expect(resizable_navigation_source).to include("height: calc(100dvh - var(--admin-navigation-top, 1rem) - var(--admin-navigation-bottom, 1rem))")
    expect(resizable_navigation_source).to include("max-height: calc(100dvh - var(--admin-navigation-top, 1rem) - var(--admin-navigation-bottom, 1rem))")
    expect(resizable_navigation_source).to include("min-height: 0")
    expect(resizable_navigation_source).to include("calc(0px - var(--admin-layout-inline-padding, 0px)) 0 0 var(--admin-layout-inline-padding, 0px)")
    expect(resizable_navigation_source).to include("0 calc(0px - var(--admin-navigation-top, 1rem)) 0 var(--admin-navigation-top, 1rem)")
    expect(resizable_navigation_source).to include("0 var(--admin-navigation-bottom, 1rem) 0 var(--admin-navigation-bottom, 1rem)")
    expect(resizable_navigation_source).to include(".admin-navigation-scroll-area .loginas")
    expect(resizable_navigation_source).to include("flex: 0 0 auto")
    expect(resizable_navigation_source).to include("overflow-y: auto")
    expect(resizable_navigation_source).to include("z-index: var(--admin-navigation-z-index, 40)")
  end

  # 固定列リサイズ後にCSS変数のleftと幅を再計算する処理があることを静的に確認する
  it "recalculates CSS sticky-left offsets after applying column widths" do
    expect(javascript_source).to include("function refreshCssStickyLeftColumns(table)")
    expect(javascript_source).to include("refreshCssStickyLeftColumnSet(table, 'sticky-left', '--sticky-left', '--sticky-width')")
    expect(javascript_source).to include("refreshCssStickyLeftColumnSet(table, 'sticky-left-mobile', '--sticky-mobile-left', '--sticky-mobile-width')")
    expect(javascript_source).to include("cell.style.setProperty(leftVariable, cssPixelValue(left))")
    expect(javascript_source).to include("refreshCssStickyLeftColumns(table)")
  end

  # 固定ヘッダー複製用のDOM/CSSクラスが残っていないことを静的に確認する
  it "removes duplicated fixed header hooks from column resize assets" do
    expect(stylesheet_source).not_to include("data-fixed-table-header")
    expect(stylesheet_source).not_to include("table-fixed-header__table")
    expect(components_source).not_to include("data-fixed-table-header")
    expect(components_source).not_to include("table-fixed-header__table")
    expect(components_source).not_to include("table-with-fixed-header")
  end

  # document全体のDOM変更監視と一時切り分け用パラメータが残っていないことを静的に確認する
  it "does not observe document mutations during table initialization" do
    expect(javascript_source).not_to include("new MutationObserver")
    expect(javascript_source).not_to include("mutationObserver.observe(document.documentElement")
    expect(javascript_source).not_to include("admin_column_resizer_disable")
    expect(javascript_source).not_to include("probeFeatureDisabled")
  end

  # 幅リセット時も固定列のCSS変数を再計算することを静的に確認する
  it "recalculates CSS sticky-left offsets after clearing a column width" do
    expect(javascript_source).to include("clearColumnWidth(columnId, scope)")
    expect(javascript_source).to include("clearTableColumnWidth(table, columnId)")
    expect(javascript_source).to include("refreshCssStickyLeftColumns(table)")
  end

  # カラム幅の初期同期と保存にlocalStorageを使わず、サーバーへのPATCHだけを使うことを確認する
  it "persists column widths through browser preferences instead of localStorage" do
    expect(javascript_source).to include("PREFERENCES_ENDPOINT = '/admin/browser_preferences'")
    expect(javascript_source).to include("window.fetch(PREFERENCES_ENDPOINT")
    expect(javascript_source).to include("preference: 'column_width'")
    expect(javascript_source).to include("scope: scope")
    expect(javascript_source).to include("column_id: columnId")
    expect(javascript_source).not_to include("localStorage")
    expect(javascript_source).not_to include("applyStoredWidthsToTables")
  end

  # サーバー側デフォルト幅はユーザー幅のfallbackとしてCSS変数に残り、リセット時に復帰できることを確認する
  it "keeps server default widths as CSS variable fallbacks" do
    expect(javascript_source).to include("DEFAULT_WIDTH_VAR_PREFIX = '--admin-column-resizer-default-col-'")
    expect(javascript_source).to include("USER_WIDTH_VAR_PREFIX = '--admin-column-resizer-user-col-'")
    expect(javascript_source).to include("defaultColumnWidthValue(table, index)")
    expect(javascript_source).to include("effectiveColumnWidthValue(index, true)")
    expect(javascript_source).to include("table.style.removeProperty(userColumnWidthVariable(index))")
    expect(javascript_source).not_to include("initializeAdjustedColumnWidths")
  end

  # 未調整のコピーセルは内容とコピーアイコンを1行で収める幅を自然幅として使うことを確認する
  it "keeps copy cells on one line until a column width is adjusted" do
    expect(components_source).to include("display: inline-flex")
    expect(components_source).to include("width: max-content")
    expect(components_source).to include("min-width: max-content")
    expect(components_source).to include("white-space: nowrap")
    expect(stylesheet_source).to include("> .admin-copy-cell")
    expect(stylesheet_source).to include("width: 100% !important")
    expect(stylesheet_source).to include("flex: 1 1 auto !important")
  end

  # 初回ロード時のJSはテーブルDOMを書き換えず、ヘッダー高さだけを測定反映することを静的に確認する
  it "does not mutate table DOM during initial column resizer setup" do
    expect(javascript_source).not_to include("table.classList.add")
    expect(javascript_source).not_to include("document.createElement('span')")
    expect(javascript_source).not_to include("appendChild(handle)")
    expect(javascript_source).not_to include("ensureColumnRules")
    expect(javascript_source).not_to include("setTimeout(initializeFromDocument")
    expect(javascript_source).to include("tablesFromRoot(root).forEach(configureTable)")
    expect(javascript_source).to include("refreshStickyHeaderLayout(root)")
  end

  # ナビゲーション幅もlocalStorageではなくブラウザ別設定へ保存することを確認する
  it "persists navigation widths through browser preferences instead of localStorage" do
    expect(resizable_navigation_javascript_source).to include('PREFERENCES_ENDPOINT = "/admin/browser_preferences"')
    expect(resizable_navigation_javascript_source).to include("window.fetch(PREFERENCES_ENDPOINT")
    expect(resizable_navigation_javascript_source).to include('preference: "navigation_width"')
    expect(resizable_navigation_javascript_source).to include("persistWidth(latestWidth)")
    expect(resizable_navigation_javascript_source).not_to include("localStorage")
  end
end
