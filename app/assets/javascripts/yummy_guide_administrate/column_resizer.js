(function() {
  var TABLE_SELECTOR = 'table[data-fixed-columns-count]';
  var HANDLE_CLASS = 'admin-column-resizer__handle';
  var HEADER_CLASS = 'admin-column-resizer__header';
  var TABLE_CLASS = 'admin-column-resizer__table';
  var DRAGGING_BODY_CLASS = 'admin-column-resizer--dragging';
  var APPLYING_BODY_CLASS = 'admin-column-resizer--applying';
  var PREVIEW_CLASS = 'admin-column-resizer__preview';
  var FIXED_HEADER_TABLE_CLASS = 'table-fixed-header__table';
  var ADJUSTED_COLUMNS_ATTRIBUTE = 'data-admin-column-resizer-adjusted-columns';
  var STORAGE_PREFIX = 'yummyGuideAdminColumnWidths:v1:';
  var STYLE_ELEMENT_ID = 'admin-column-resizer-rules';
  var WIDTH_VAR_PREFIX = '--admin-column-resizer-col-';
  var MIN_WIDTH = 48;

  var dragState = null;
  var dragPreviewFrame = null;
  var widthApplyFrame = null;
  var pendingWidthApply = null;
  var generatedRuleCount = 0;
  var initializedHandles = new WeakSet();
  var tableStates = new WeakMap();
  var stickyRefreshFrame = null;
  var stickyRefreshCallbacks = [];
  var applyingWidth = false;

  function storageScopeForTable(table) {
    var sourceTable = matchingSourceTable(table);
    var scopedTable = sourceTable || table;
    var scope = scopedTable && scopedTable.getAttribute('data-column-resizer-storage-scope');

    return scope || window.location.pathname;
  }

  function storageKeyForTable(table) {
    return STORAGE_PREFIX + storageScopeForTable(table);
  }

  function parsedWidths(rawWidths) {
    if (!rawWidths) return {};

    var widths = JSON.parse(rawWidths);
    return widths && typeof widths === 'object' && !Array.isArray(widths) ? widths : {};
  }

  function safeReadWidths(key) {
    try {
      return parsedWidths(window.localStorage.getItem(key));
    } catch (_error) {
      return {};
    }
  }

  function safeWriteWidths(key, widths) {
    try {
      if (Object.keys(widths).length === 0) {
        window.localStorage.removeItem(key);
      } else {
        window.localStorage.setItem(key, JSON.stringify(widths));
      }
    } catch (_error) {
      // localStorage may be unavailable in private browsing or restricted contexts.
    }
  }

  function preciseNumber(value) {
    return Math.round(value * 1000) / 1000;
  }

  function cssPixelValue(value) {
    return preciseNumber(value) + 'px';
  }

  function measuredWidth(element) {
    if (!element) return 0;

    var rectWidth = element.getBoundingClientRect().width;
    return preciseNumber(rectWidth || element.offsetWidth || 0);
  }

  function viewportHeight() {
    return window.innerHeight || document.documentElement.clientHeight || 0;
  }

  function normalizedIdentifier(value) {
    return (value || '').toString().trim().toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 80) || 'column';
  }

  function directCells(row) {
    return Array.from(row.children).filter(function(cell) {
      return cell.tagName === 'TH' || cell.tagName === 'TD';
    });
  }

  function columnHeaders(table) {
    var row = table.querySelector('thead tr');
    if (!row) return [];

    return directCells(row).filter(function(cell) {
      return cell.tagName === 'TH';
    });
  }

  function headerLabel(header) {
    return (header.getAttribute('aria-label') || header.getAttribute('title') || header.textContent || '')
      .trim()
      .replace(/\s+/g, ' ');
  }

  function headerSignature(table) {
    return columnHeaders(table).map(function(header, index) {
      return normalizedIdentifier(header.dataset.columnId || headerLabel(header) || ('column_' + (index + 1)));
    }).join('__');
  }

  function matchingSourceTable(table) {
    if (!table) return null;
    if (!table.classList.contains(FIXED_HEADER_TABLE_CLASS)) return null;

    var signature = headerSignature(table);
    return sourceTables().find(function(sourceTable) {
      return headerSignature(sourceTable) === signature;
    }) || null;
  }

  function tableIdentifier(table) {
    if (table.dataset.adminColumnResizerTableId) return table.dataset.adminColumnResizerTableId;

    var sourceTable = matchingSourceTable(table);
    if (sourceTable) {
      table.dataset.adminColumnResizerTableId = tableIdentifier(sourceTable);
      return table.dataset.adminColumnResizerTableId;
    }

    var tableLabel = table.id ||
      table.getAttribute('aria-labelledby') ||
      table.getAttribute('data-admin-column-resizer-table') ||
      table.getAttribute('data-fixed-header-source');

    if (!tableLabel) {
      var index = sourceTables().indexOf(table);
      tableLabel = 'table_' + (index >= 0 ? index + 1 : allTrackedTables().indexOf(table) + 1);
    }

    table.dataset.adminColumnResizerTableId = normalizedIdentifier(tableLabel);
    return table.dataset.adminColumnResizerTableId;
  }

  function fallbackColumnId(table, header, index) {
    return [
      'fallback',
      tableIdentifier(table),
      index + 1,
      normalizedIdentifier(headerLabel(header))
    ].join('.');
  }

  function headerColumnId(header) {
    return header.dataset.adminColumnResizerColumnId || header.dataset.columnId || '';
  }

  function assignHeaderColumnId(table, header, index) {
    if (header.colSpan && header.colSpan > 1) return '';

    var columnId = header.dataset.columnId || fallbackColumnId(table, header, index);
    header.dataset.adminColumnResizerColumnId = columnId;
    return columnId;
  }

  function columnWidthVariable(index) {
    return WIDTH_VAR_PREFIX + (index + 1);
  }

  function columnRule(index) {
    var nthChild = index + 1;
    var variableName = columnWidthVariable(index);
    var adjustedTableSelector = '.' + TABLE_CLASS + '[' + ADJUSTED_COLUMNS_ATTRIBUTE + '~="' + nthChild + '"]';
    var selectors = [
      adjustedTableSelector + ' > thead > tr > :nth-child(' + nthChild + ')',
      adjustedTableSelector + ' > tbody > tr > :nth-child(' + nthChild + ')',
      adjustedTableSelector + ' > tfoot > tr > :nth-child(' + nthChild + ')'
    ];
    var selector = selectors.join(', ');

    var contentSelector = selectors.concat(selectors.map(function(cellSelector) {
      return cellSelector + ' *';
    })).join(', ');

    return [
      selector + ' { box-sizing: border-box !important; width: var(' + variableName + ') !important; min-width: var(' + variableName + ') !important; max-width: var(' + variableName + ') !important; }',
      contentSelector + ' { white-space: normal !important; overflow-wrap: anywhere !important; word-break: break-word !important; }'
    ].join('\n');
  }

  function ensureStyleElement() {
    var styleElement = document.getElementById(STYLE_ELEMENT_ID);
    if (styleElement) return styleElement;

    styleElement = document.createElement('style');
    styleElement.id = STYLE_ELEMENT_ID;
    document.head.appendChild(styleElement);

    return styleElement;
  }

  function ensureColumnRules(columnCount) {
    if (columnCount <= generatedRuleCount) return;

    var rules = [];
    for (var index = generatedRuleCount; index < columnCount; index += 1) {
      rules.push(columnRule(index));
    }

    ensureStyleElement().appendChild(document.createTextNode(rules.join('\n') + '\n'));
    generatedRuleCount = columnCount;
  }

  function tablesFromRoot(root) {
    var tables = [];

    function appendTable(table) {
      if (table && tables.indexOf(table) === -1) {
        tables.push(table);
      }
    }

    if (root.closest) {
      appendTable(root.closest(TABLE_SELECTOR));
    }

    if (root.matches && root.matches(TABLE_SELECTOR)) {
      appendTable(root);
    }

    if (root.querySelectorAll) {
      root.querySelectorAll(TABLE_SELECTOR).forEach(appendTable);
    }

    return tables;
  }

  function shouldInitializeForAddedNode(node) {
    if (!node.matches) return false;
    if (node.matches(TABLE_SELECTOR) || (node.querySelector && node.querySelector(TABLE_SELECTOR))) return true;
    if (!node.closest || !node.closest(TABLE_SELECTOR)) return false;

    return !!node.closest('thead') || node.matches('colgroup, col');
  }

  function allTrackedTables() {
    return Array.from(document.querySelectorAll(TABLE_SELECTOR));
  }

  function sourceTables() {
    return allTrackedTables().filter(function(table) {
      return table.getAttribute('aria-hidden') !== 'true' && !table.classList.contains(FIXED_HEADER_TABLE_CLASS);
    });
  }

  function stateForTable(table) {
    return tableStates.get(table) || configureTable(table);
  }

  function ensureManagedColgroup(table, columnCount) {
    var fixedHeaderColgroup = table.querySelector('colgroup[data-fixed-header-colgroup]');
    var colgroup = fixedHeaderColgroup || table.querySelector('colgroup[data-admin-column-resizer-colgroup]');

    if (!colgroup) {
      colgroup = document.createElement('colgroup');
      colgroup.setAttribute('data-admin-column-resizer-colgroup', 'true');
      table.insertBefore(colgroup, table.firstChild);
    }

    while (colgroup.children.length < columnCount) {
      colgroup.appendChild(document.createElement('col'));
    }

    return colgroup;
  }

  function configureTable(table) {
    var headers = columnHeaders(table);
    if (headers.length === 0) return null;

    var indexByColumnId = Object.create(null);

    headers.forEach(function(header, index) {
      var columnId = assignHeaderColumnId(table, header, index);
      if (!columnId) return;

      if (indexByColumnId[columnId] === undefined) {
        indexByColumnId[columnId] = index;
      }

      ensureHandle(header);
    });

    table.classList.add(TABLE_CLASS);
    ensureColumnRules(headers.length);
    ensureManagedColgroup(table, headers.length);

    var state = {
      columnCount: headers.length,
      indexByColumnId: indexByColumnId
    };
    tableStates.set(table, state);

    return state;
  }

  function columnIndex(table, columnId) {
    var state = stateForTable(table);
    if (!state || state.indexByColumnId[columnId] === undefined) return -1;

    return state.indexByColumnId[columnId];
  }

  function columnHeader(table, columnId) {
    var index = columnIndex(table, columnId);
    if (index < 0) return null;

    return columnHeaders(table)[index] || null;
  }

  function applyColgroupWidth(table, columnCount, index, widthValue) {
    var colgroup = ensureManagedColgroup(table, columnCount);
    if (!colgroup || !colgroup.children[index]) return;

    colgroup.children[index].style.width = widthValue;
  }

  function adjustedColumnIndexes(table) {
    return (table.getAttribute(ADJUSTED_COLUMNS_ATTRIBUTE) || '')
      .split(/\s+/)
      .filter(Boolean);
  }

  function setAdjustedColumn(table, index, adjusted) {
    var indexToken = (index + 1).toString();
    var indexes = adjustedColumnIndexes(table).filter(function(candidate, candidateIndex, candidates) {
      return candidate !== indexToken && candidates.indexOf(candidate) === candidateIndex;
    });

    if (adjusted) {
      indexes.push(indexToken);
      indexes.sort(function(left, right) {
        return parseInt(left, 10) - parseInt(right, 10);
      });
    }

    if (indexes.length === 0) {
      table.removeAttribute(ADJUSTED_COLUMNS_ATTRIBUTE);
      return;
    }

    table.setAttribute(ADJUSTED_COLUMNS_ATTRIBUTE, indexes.join(' '));
  }

  function clearColgroupWidth(table, columnCount, index) {
    var colgroup = ensureManagedColgroup(table, columnCount);
    if (!colgroup || !colgroup.children[index]) return;

    colgroup.children[index].style.removeProperty('width');
  }

  function applyTableColumnWidth(table, columnId, width) {
    var state = stateForTable(table);
    var index = state && state.indexByColumnId[columnId];
    if (!state || index === undefined) return;

    var widthValue = cssPixelValue(width);
    table.style.setProperty(columnWidthVariable(index), widthValue);
    setAdjustedColumn(table, index, true);
    applyColgroupWidth(table, state.columnCount, index, widthValue);
  }

  function clearTableColumnWidth(table, columnId) {
    var state = stateForTable(table);
    var index = state && state.indexByColumnId[columnId];
    if (!state || index === undefined) return;

    table.style.removeProperty(columnWidthVariable(index));
    setAdjustedColumn(table, index, false);
    clearColgroupWidth(table, state.columnCount, index);
  }

  function applyColumnWidth(columnId, width, key) {
    allTrackedTables().forEach(function(table) {
      if (key && storageKeyForTable(table) !== key) return;

      applyTableColumnWidth(table, columnId, width);
    });
  }

  function clearColumnWidth(columnId, key) {
    allTrackedTables().forEach(function(table) {
      if (key && storageKeyForTable(table) !== key) return;

      clearTableColumnWidth(table, columnId);
    });
  }

  function applyStoredWidthsToTable(table, widths) {
    Object.keys(widths).forEach(function(columnId) {
      var width = parseFloat(widths[columnId]);
      if (Number.isNaN(width) || width < MIN_WIDTH) return;

      applyTableColumnWidth(table, columnId, width);
    });
  }

  function applyStoredWidthsToTables(tables) {
    if (dragState) return;

    var widthsByStorageKey = Object.create(null);

    tables.forEach(function(table) {
      var key = storageKeyForTable(table);
      widthsByStorageKey[key] = widthsByStorageKey[key] || safeReadWidths(key);

      applyStoredWidthsToTable(table, widthsByStorageKey[key]);
    });
  }

  function dispatchStickyRefresh() {
    stickyRefreshFrame = null;
    window.dispatchEvent(new Event('resize'));

    var callbacks = stickyRefreshCallbacks;
    stickyRefreshCallbacks = [];
    callbacks.forEach(function(callback) {
      callback();
    });
  }

  function scheduleStickyRefresh(callback) {
    if (callback) {
      stickyRefreshCallbacks.push(callback);
    }

    if (stickyRefreshFrame) return;

    stickyRefreshFrame = window.requestAnimationFrame(dispatchStickyRefresh);
  }

  function sourceTableForHandle(handle) {
    var header = handle.closest('th');
    if (!header) return null;

    var table = handle.closest(TABLE_SELECTOR);
    var columnId = headerColumnId(header);

    if (table && table.getAttribute('aria-hidden') !== 'true' && !table.classList.contains(FIXED_HEADER_TABLE_CLASS)) {
      return table;
    }

    return sourceTables().find(function(sourceTable) {
      return columnHeader(sourceTable, columnId);
    }) || matchingSourceTable(table) || null;
  }

  function previewBoundsForTable(table, header) {
    var headerRect = header.getBoundingClientRect();
    var tableRect = table.getBoundingClientRect();
    var scrollContainer = table.closest('.sticky-table-scroll, .scroll-table, .home-table__wrapper');
    var scrollRect = scrollContainer ? scrollContainer.getBoundingClientRect() : tableRect;
    var headerTable = header.closest(TABLE_SELECTOR);
    var fromFixedHeader = headerTable && headerTable.classList.contains(FIXED_HEADER_TABLE_CLASS);
    var viewportBottom = viewportHeight();
    var top = fromFixedHeader ? headerRect.top : Math.max(tableRect.top, scrollRect.top);
    var bottom = Math.min(viewportBottom, Math.max(tableRect.bottom, scrollRect.bottom, headerRect.bottom));

    top = Math.max(0, Math.min(top, viewportBottom));
    if (bottom <= top) {
      bottom = Math.min(viewportBottom, top + Math.max(headerRect.height, 32));
    }

    return {
      left: headerRect.left,
      top: top,
      height: Math.max(32, bottom - top)
    };
  }

  function updateDragPreview(preview, width) {
    if (!preview) return;

    preview.element.style.width = cssPixelValue(width);
  }

  function createDragPreview(table, header, width) {
    var bounds = previewBoundsForTable(table, header);
    var element = document.createElement('div');

    element.className = PREVIEW_CLASS;
    element.setAttribute('aria-hidden', 'true');
    element.style.left = cssPixelValue(bounds.left);
    element.style.top = cssPixelValue(bounds.top);
    element.style.height = cssPixelValue(bounds.height);

    document.body.appendChild(element);

    var preview = {
      element: element
    };
    updateDragPreview(preview, width);

    return preview;
  }

  function removePreview(preview) {
    if (!preview) return;

    preview.element.remove();
  }

  function removeDragPreview() {
    if (!dragState || !dragState.preview) return;

    removePreview(dragState.preview);
    dragState.preview = null;
  }

  function flushDragPreview() {
    if (!dragState) return;

    if (dragPreviewFrame) {
      window.cancelAnimationFrame(dragPreviewFrame);
      dragPreviewFrame = null;
    }

    updateDragPreview(dragState.preview, dragState.currentWidth || dragState.startWidth);
  }

  function releaseDragPointerCapture() {
    if (!dragState || !dragState.handle || dragState.pointerId === null || typeof dragState.pointerId === 'undefined') return;
    if (!dragState.handle.releasePointerCapture) return;

    try {
      dragState.handle.releasePointerCapture(dragState.pointerId);
    } catch (_error) {
      // The pointer may already be released by the browser after cancellation.
    }
  }

  function captureDragPointer(handle, event) {
    if (!handle.setPointerCapture || event.pointerId === null || typeof event.pointerId === 'undefined') return;

    try {
      handle.setPointerCapture(event.pointerId);
    } catch (_error) {
      // Pointer capture is an enhancement for touch/pen dragging; document listeners remain as fallback.
    }
  }

  function eventMatchesDragPointer(event) {
    return !event ||
      dragState.pointerId === null ||
      typeof dragState.pointerId === 'undefined' ||
      event.pointerId === dragState.pointerId;
  }

  function pointerCanStartDrag(event) {
    if (event.isPrimary === false) return false;

    return event.pointerType !== 'mouse' || event.button === 0;
  }

  function stopDragging(removePreview) {
    if (!dragState) return null;

    if (dragPreviewFrame) {
      window.cancelAnimationFrame(dragPreviewFrame);
      dragPreviewFrame = null;
    }

    if (removePreview) {
      removeDragPreview();
    }

    releaseDragPointerCapture();

    var completedDrag = dragState;
    dragState = null;
    document.body.classList.remove(DRAGGING_BODY_CLASS);
    document.removeEventListener('pointermove', handleDragMove);
    document.removeEventListener('pointerup', finishDrag);
    document.removeEventListener('pointercancel', finishDrag);

    return completedDrag;
  }

  function scheduleDragWidth(width) {
    dragState.currentWidth = width;
    dragState.moved = dragState.moved || Math.abs(width - dragState.startWidth) > 2;

    if (dragPreviewFrame) return;

    dragPreviewFrame = window.requestAnimationFrame(function() {
      dragPreviewFrame = null;
      if (!dragState) return;

      updateDragPreview(dragState.preview, dragState.currentWidth);
    });
  }

  function refreshStickyHeaderColumn(pendingWidth, callback) {
    var api = window.YummyGuideAdministrateStickyTableHeaders;

    if (api && typeof api.refreshColumnWidth === 'function') {
      var refreshed = api.refreshColumnWidth({
        sourceTable: pendingWidth.sourceTable,
        columnId: pendingWidth.columnId,
        width: pendingWidth.width
      });

      if (refreshed) {
        window.requestAnimationFrame(callback);
        return;
      }
    }

    scheduleStickyRefresh(callback);
  }

  function refreshStickyHeaderTable(sourceTable, callback) {
    var api = window.YummyGuideAdministrateStickyTableHeaders;

    if (api && typeof api.refreshTable === 'function') {
      var refreshed = api.refreshTable(sourceTable, callback);

      if (refreshed) return;
    }

    scheduleStickyRefresh(callback);
  }

  function refreshStickyLeftColumns(sourceTable) {
    var api = window.YummyGuideAdministrateStickyLeftColumns;

    if (api && typeof api.refreshTable === 'function') {
      api.refreshTable(sourceTable);
    }
  }

  function refreshStickyLeftColumnsForWidth(pendingWidth) {
    var api = window.YummyGuideAdministrateStickyLeftColumns;

    if (!api) return;

    if (typeof api.refreshColumnWidth === 'function') {
      var refreshed = api.refreshColumnWidth({
        sourceTable: pendingWidth.sourceTable,
        columnId: pendingWidth.columnId,
        width: pendingWidth.width
      });

      if (refreshed) return;
    }

    refreshStickyLeftColumns(pendingWidth.sourceTable);
  }

  function startApplyingWidth() {
    applyingWidth = true;
    document.body.classList.add(APPLYING_BODY_CLASS);
  }

  function stopApplyingState() {
    applyingWidth = false;
    document.body.classList.remove(APPLYING_BODY_CLASS);
  }

  function stopApplyingWidth(preview) {
    removePreview(preview);
    pendingWidthApply = null;
    stopApplyingState();
  }

  function cancelPendingWidthApply() {
    if (widthApplyFrame) {
      window.cancelAnimationFrame(widthApplyFrame);
      widthApplyFrame = null;
    }

    if (pendingWidthApply) {
      removePreview(pendingWidthApply.preview);
      pendingWidthApply = null;
    }

    stopApplyingState();
  }

  function applyPendingWidth(pendingWidth) {
    try {
      var widths = safeReadWidths(pendingWidth.storageKey);
      applyColumnWidth(pendingWidth.columnId, pendingWidth.width, pendingWidth.storageKey);
      widths[pendingWidth.columnId] = preciseNumber(pendingWidth.width);
      safeWriteWidths(pendingWidth.storageKey, widths);
      refreshStickyLeftColumnsForWidth(pendingWidth);
      refreshStickyHeaderColumn(pendingWidth, function() {
        stopApplyingWidth(pendingWidth.preview);
      });
    } catch (error) {
      stopApplyingWidth(pendingWidth.preview);
      throw error;
    }
  }

  function schedulePendingWidthApply(pendingWidth) {
    pendingWidthApply = pendingWidth;
    startApplyingWidth();

    widthApplyFrame = window.requestAnimationFrame(function() {
      widthApplyFrame = window.requestAnimationFrame(function() {
        widthApplyFrame = null;
        applyPendingWidth(pendingWidth);
      });
    });
  }

  function startDrag(event) {
    if (!pointerCanStartDrag(event)) return;
    if (applyingWidth || widthApplyFrame) return;

    var handle = event.currentTarget;
    var header = handle.closest('th');
    if (!header) return;

    var columnId = headerColumnId(header);
    if (!columnId) return;

    var sourceTable = sourceTableForHandle(handle);
    if (!sourceTable) return;

    var sourceHeader = columnHeader(sourceTable, columnId) || header;
    var sourceHeaderWidth = measuredWidth(sourceHeader);
    var handleHeaderWidth = measuredWidth(header);
    var startWidth = sourceHeaderWidth || handleHeaderWidth;
    if (!startWidth) return;
    var previewHeader = sourceHeaderWidth ? sourceHeader : header;

    event.preventDefault();
    event.stopPropagation();

    dragState = {
      columnId: columnId,
      storageKey: storageKeyForTable(sourceTable),
      startX: event.clientX,
      startWidth: startWidth,
      currentWidth: startWidth,
      pointerId: event.pointerId,
      handle: handle,
      sourceTable: sourceTable,
      moved: false,
      preview: createDragPreview(sourceTable, previewHeader, startWidth)
    };

    captureDragPointer(handle, event);
    document.body.classList.add(DRAGGING_BODY_CLASS);
    document.addEventListener('pointermove', handleDragMove);
    document.addEventListener('pointerup', finishDrag);
    document.addEventListener('pointercancel', finishDrag);
  }

  function handleDragMove(event) {
    if (!dragState) return;
    if (!eventMatchesDragPointer(event)) return;

    event.preventDefault();

    scheduleDragWidth(Math.max(MIN_WIDTH, dragState.startWidth + event.clientX - dragState.startX));
  }

  function finishDrag(event) {
    if (!dragState) return;
    if (!eventMatchesDragPointer(event)) return;

    if (event) {
      event.preventDefault();
    }

    flushDragPreview();
    var pointerCancelled = event && event.type === 'pointercancel';
    var shouldApplyWidth = dragState.moved && !pointerCancelled;

    var pendingWidth = {
      columnId: dragState.columnId,
      storageKey: dragState.storageKey,
      sourceTable: dragState.sourceTable,
      width: Math.max(MIN_WIDTH, dragState.currentWidth || dragState.startWidth),
      preview: dragState.preview
    };

    stopDragging(!shouldApplyWidth);
    if (!shouldApplyWidth) return;

    schedulePendingWidthApply(pendingWidth);
  }

  function resetColumn(event) {
    var handle = event.currentTarget;
    var header = handle.closest('th');
    if (!header) return;

    var columnId = headerColumnId(header);
    if (!columnId) return;

    event.preventDefault();
    event.stopPropagation();
    cancelPendingWidthApply();
    stopDragging(true);

    var sourceTable = sourceTableForHandle(handle);
    var key = storageKeyForTable(sourceTable || handle.closest(TABLE_SELECTOR));
    var widths = safeReadWidths(key);
    delete widths[columnId];
    safeWriteWidths(key, widths);
    clearColumnWidth(columnId, key);
    startApplyingWidth();
    if (sourceTable) {
      refreshStickyHeaderTable(sourceTable, function() {
        refreshStickyLeftColumns(sourceTable);
        stopApplyingWidth(null);
      });
    } else {
      scheduleStickyRefresh(function() {
        stopApplyingWidth(null);
      });
    }
  }

  function stopHandleClick(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  function ensureHandle(header) {
    if (!headerColumnId(header)) return;

    header.classList.add(HEADER_CLASS);

    var handle = Array.from(header.children).find(function(child) {
      return child.classList && child.classList.contains(HANDLE_CLASS);
    });

    if (!handle) {
      handle = document.createElement('span');
      handle.className = HANDLE_CLASS;
      handle.setAttribute('aria-hidden', 'true');
      header.appendChild(handle);
    }

    if (initializedHandles.has(handle)) return;

    initializedHandles.add(handle);
    handle.addEventListener('pointerdown', startDrag);
    handle.addEventListener('dblclick', resetColumn);
    handle.addEventListener('click', stopHandleClick);
  }

  function initializeTable(table) {
    return configureTable(table);
  }

  function initializeColumnResizer(root) {
    if (!root.querySelectorAll) return;

    var configuredTables = tablesFromRoot(root).filter(function(table) {
      return !!initializeTable(table);
    });

    applyStoredWidthsToTables(configuredTables);
  }

  function initializeFromDocument() {
    initializeColumnResizer(document);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeFromDocument);
  } else {
    initializeFromDocument();
  }

  document.addEventListener('turbo:load', initializeFromDocument);
  window.addEventListener('resize', initializeFromDocument);

  if (window.MutationObserver) {
    var mutationObserver = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType !== Node.ELEMENT_NODE) return;
          if (!shouldInitializeForAddedNode(node)) return;

          initializeColumnResizer(node);
        });
      });
    });

    mutationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }

  setTimeout(initializeFromDocument, 100);
  setTimeout(initializeFromDocument, 300);
})();
