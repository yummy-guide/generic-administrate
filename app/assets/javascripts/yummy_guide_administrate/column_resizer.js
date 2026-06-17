(function() {
  var TABLE_SELECTOR = 'table[data-fixed-columns-count]';
  var CSS_STICKY_TABLE_SELECTOR = '[data-css-sticky-table]';
  var MAIN_CONTENT_SELECTOR = '.main-content';
  var STICKY_PAGE_HEADER_SELECTOR = '.main-content__header--sticky-table-layout, [data-reservations-sticky-header], .main-content__header';
  var STICKY_PAGE_HEADER_HEIGHT_VARIABLE = '--admin-sticky-page-header-height';
  var RESIZE_HEADER_SELECTOR = 'th[data-admin-column-resizer-column-id], th[data-column-id]';
  var DRAGGING_BODY_CLASS = 'admin-column-resizer--dragging';
  var APPLYING_BODY_CLASS = 'admin-column-resizer--applying';
  var PREVIEW_CLASS = 'admin-column-resizer__preview';
  var ADJUSTED_COLUMNS_ATTRIBUTE = 'data-admin-column-resizer-adjusted-columns';
  var PREFERENCES_ENDPOINT = '/admin/browser_preferences';
  var WIDTH_VAR_PREFIX = '--admin-column-resizer-col-';
  var DEFAULT_WIDTH_VAR_PREFIX = '--admin-column-resizer-default-col-';
  var USER_WIDTH_VAR_PREFIX = '--admin-column-resizer-user-col-';
  var MIN_WIDTH = 48;
  var DESKTOP_GUTTER_LEFT = 8;
  var DESKTOP_GUTTER_RIGHT = 8;
  var COARSE_GUTTER_LEFT = 28;
  var COARSE_GUTTER_RIGHT = 8;
  var WINDOW_RESIZE_REFRESH_DELAY = 500;

  var dragState = null;
  var dragPreviewFrame = null;
  var widthApplyFrame = null;
  var pendingWidthApply = null;
  var tableStates = new WeakMap();
  var stickyPageHeaderLayoutFrames = new WeakMap();
  var stickyTableMainContents = new Set();
  var applyingWidth = false;
  var resizeEventsInitialized = false;
  var resizeRefreshTimer = null;

  function storageScopeForTable(table) {
    var scope = table && table.getAttribute('data-column-resizer-storage-scope');

    return scope || window.location.pathname;
  }

  function preciseNumber(value) {
    return Math.round(value * 1000) / 1000;
  }

  function cssPixelValue(value) {
    return preciseNumber(value) + 'px';
  }

  function parsedPixelValue(value) {
    var parsedValue = parseFloat(value || '0');
    return Number.isNaN(parsedValue) ? 0 : preciseNumber(parsedValue);
  }

  function measuredWidth(element) {
    if (!element) return 0;

    var rectWidth = element.getBoundingClientRect().width;
    return preciseNumber(rectWidth || element.offsetWidth || 0);
  }

  function pushUnique(array, item) {
    if (item && array.indexOf(item) === -1) {
      array.push(item);
    }
  }

  function hasCssStickyTable(element) {
    if (!element) return false;

    return (element.matches && element.matches(CSS_STICKY_TABLE_SELECTOR)) ||
      !!(element.querySelector && element.querySelector(CSS_STICKY_TABLE_SELECTOR));
  }

  function closestMainContent(element) {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) return null;

    if (element.matches && element.matches(MAIN_CONTENT_SELECTOR)) {
      return element;
    }

    return element.closest ? element.closest(MAIN_CONTENT_SELECTOR) : null;
  }

  function collectStickyTableMainContents(root) {
    var mainContents = [];
    var element = root && root.nodeType === Node.ELEMENT_NODE ? root : null;

    if (element) {
      pushUnique(mainContents, closestMainContent(element));

      if (element.matches && element.matches(CSS_STICKY_TABLE_SELECTOR)) {
        pushUnique(mainContents, closestMainContent(element));
      }
    }

    if (root && root.querySelectorAll) {
      root.querySelectorAll(MAIN_CONTENT_SELECTOR).forEach(function(mainContent) {
        if (hasCssStickyTable(mainContent)) {
          pushUnique(mainContents, mainContent);
        }
      });

      root.querySelectorAll(CSS_STICKY_TABLE_SELECTOR).forEach(function(tableWrapper) {
        pushUnique(mainContents, closestMainContent(tableWrapper));
      });
    }

    return mainContents;
  }

  function trackStickyTableMainContent(mainContent) {
    if (mainContent && hasCssStickyTable(mainContent)) {
      stickyTableMainContents.add(mainContent);
    }
  }

  function trackStickyTable(table) {
    trackStickyTableMainContent(closestMainContent(table));
  }

  function stickyPageHeader(mainContent) {
    if (!mainContent) return null;

    return Array.from(mainContent.children).find(function(child) {
      return child.matches && child.matches(STICKY_PAGE_HEADER_SELECTOR);
    }) || null;
  }

  function measuredStickyPageHeaderHeight(mainContent, header) {
    var previousHeight = mainContent.style.getPropertyValue(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);

    if (previousHeight) {
      mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);
    }

    var rectHeight = header.getBoundingClientRect().height;
    var scrollHeight = header.scrollHeight || 0;
    var height = Math.max(rectHeight || 0, scrollHeight);

    if (previousHeight) {
      mainContent.style.setProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE, previousHeight);
    }

    return preciseNumber(height);
  }

  function refreshStickyPageHeaderLayout(mainContent) {
    if (!mainContent) return false;

    if (!hasCssStickyTable(mainContent)) {
      mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);
      return false;
    }

    var header = stickyPageHeader(mainContent);

    if (!header) {
      mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);
      return false;
    }

    var height = measuredStickyPageHeaderHeight(mainContent, header);

    if (height > 0) {
      var value = cssPixelValue(height);

      if (mainContent.style.getPropertyValue(STICKY_PAGE_HEADER_HEIGHT_VARIABLE) !== value) {
        mainContent.style.setProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE, value);
      }
    } else {
      mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);
    }

    return true;
  }

  function scheduleStickyPageHeaderLayout(mainContent) {
    if (!mainContent || stickyPageHeaderLayoutFrames.has(mainContent)) return;

    var frame = window.requestAnimationFrame(function() {
      stickyPageHeaderLayoutFrames.delete(mainContent);
      refreshStickyPageHeaderLayout(mainContent);
    });

    stickyPageHeaderLayoutFrames.set(mainContent, frame);
  }

  function refreshStickyHeaderLayout(root) {
    var refreshed = false;

    collectStickyTableMainContents(root || document).forEach(function(mainContent) {
      trackStickyTableMainContent(mainContent);
      refreshed = refreshStickyPageHeaderLayout(mainContent) || refreshed;
    });

    return refreshed;
  }

  function refreshTrackedStickyHeaderLayout() {
    var refreshed = false;

    stickyTableMainContents.forEach(function(mainContent) {
      if (!mainContent || !document.documentElement.contains(mainContent)) {
        stickyTableMainContents.delete(mainContent);
        return;
      }

      if (!hasCssStickyTable(mainContent)) {
        mainContent.style.removeProperty(STICKY_PAGE_HEADER_HEIGHT_VARIABLE);
        stickyTableMainContents.delete(mainContent);
        return;
      }

      refreshed = refreshStickyPageHeaderLayout(mainContent) || refreshed;
    });

    return refreshed;
  }

  function refreshStickyHeaderLayoutForTable(table) {
    var mainContent = closestMainContent(table);

    if (!mainContent) return false;

    scheduleStickyPageHeaderLayout(mainContent);
    return true;
  }

  function scheduleWindowResizeRefresh() {
    if (resizeRefreshTimer) {
      window.clearTimeout(resizeRefreshTimer);
    }

    resizeRefreshTimer = window.setTimeout(function() {
      resizeRefreshTimer = null;
      refreshTrackedStickyHeaderLayout();
    }, WINDOW_RESIZE_REFRESH_DELAY);
  }

  function viewportHeight() {
    return window.innerHeight || document.documentElement.clientHeight || 0;
  }

  function viewportWidth() {
    return window.innerWidth || document.documentElement.clientWidth || 0;
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

  function headerColumnId(header) {
    return header.dataset.adminColumnResizerColumnId || header.dataset.columnId || '';
  }

  function columnWidthVariable(index) {
    return WIDTH_VAR_PREFIX + (index + 1);
  }

  function defaultColumnWidthVariable(index) {
    return DEFAULT_WIDTH_VAR_PREFIX + (index + 1);
  }

  function userColumnWidthVariable(index) {
    return USER_WIDTH_VAR_PREFIX + (index + 1);
  }

  function effectiveColumnWidthValue(index, hasDefaultWidth) {
    var userVariable = 'var(' + userColumnWidthVariable(index) + ')';

    if (!hasDefaultWidth) return userVariable;

    return 'var(' + userColumnWidthVariable(index) + ', var(' + defaultColumnWidthVariable(index) + '))';
  }

  function defaultColumnWidthValue(table, index) {
    return (table.style.getPropertyValue(defaultColumnWidthVariable(index)) || '').trim();
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

  function allTrackedTables() {
    return Array.from(document.querySelectorAll(TABLE_SELECTOR));
  }

  function stateForTable(table) {
    return tableStates.get(table) || configureTable(table);
  }

  function ensureManagedColgroup(table, columnCount) {
    var colgroup = table.querySelector('colgroup[data-admin-column-resizer-colgroup]');

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
      var columnId = headerColumnId(header);
      if (!columnId) return;

      if (indexByColumnId[columnId] === undefined) {
        indexByColumnId[columnId] = index;
      }
    });

    var state = {
      headers: headers,
      columnCount: headers.length,
      indexByColumnId: indexByColumnId
    };
    tableStates.set(table, state);
    trackStickyTable(table);

    return state;
  }

  function columnHeader(table, columnId) {
    var state = stateForTable(table);
    var index = state && state.indexByColumnId[columnId];
    if (!state || index === undefined) return null;

    return state.headers[index] || null;
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
    table.style.setProperty(userColumnWidthVariable(index), widthValue);
    table.style.setProperty(columnWidthVariable(index), effectiveColumnWidthValue(index, !!defaultColumnWidthValue(table, index)));
    setAdjustedColumn(table, index, true);
    applyColgroupWidth(table, state.columnCount, index, widthValue);
    return true;
  }

  function clearTableColumnWidth(table, columnId) {
    var state = stateForTable(table);
    var index = state && state.indexByColumnId[columnId];
    if (!state || index === undefined) return;

    var defaultWidth = defaultColumnWidthValue(table, index);
    table.style.removeProperty(userColumnWidthVariable(index));

    if (defaultWidth) {
      table.style.setProperty(columnWidthVariable(index), effectiveColumnWidthValue(index, true));
      setAdjustedColumn(table, index, true);
      applyColgroupWidth(table, state.columnCount, index, defaultWidth);
    } else {
      table.style.removeProperty(columnWidthVariable(index));
      setAdjustedColumn(table, index, false);
      clearColgroupWidth(table, state.columnCount, index);
    }

    return true;
  }

  function stickyColumnIndexes(table, className) {
    var row = table && table.querySelector('thead tr');
    if (!row) return [];

    return directCells(row).map(function(cell, index) {
      return cell.classList && cell.classList.contains(className) ? index : null;
    }).filter(function(index) {
      return index !== null;
    });
  }

  function managedColumnWidth(table, index) {
    var colgroup = table && table.querySelector('colgroup[data-admin-column-resizer-colgroup]');
    var col = colgroup && colgroup.children[index];

    return col ? parsedPixelValue(col.style.width) : 0;
  }

  function stickyColumnWidth(table, header, index, widthVariable) {
    return measuredWidth(header) ||
      managedColumnWidth(table, index) ||
      parsedPixelValue(header && header.style && header.style.getPropertyValue(widthVariable));
  }

  function applyStickyColumnPosition(table, index, leftVariable, left, widthVariable, width) {
    Array.from(table.querySelectorAll('thead tr, tbody tr, tfoot tr')).forEach(function(row) {
      var cell = directCells(row)[index];
      if (!cell) return;

      cell.style.setProperty(leftVariable, cssPixelValue(left));
      if (width) {
        cell.style.setProperty(widthVariable, cssPixelValue(width));
      }
    });
  }

  function refreshCssStickyLeftColumnSet(table, className, leftVariable, widthVariable) {
    var headerRow = table && table.querySelector('thead tr');
    if (!headerRow) return;

    var headerCells = directCells(headerRow);
    var left = 0;

    stickyColumnIndexes(table, className).forEach(function(index) {
      var width = stickyColumnWidth(table, headerCells[index], index, widthVariable);

      applyStickyColumnPosition(table, index, leftVariable, left, widthVariable, width);
      left += width;
    });
  }

  function refreshCssStickyLeftColumns(table) {
    if (!table || table.getAttribute('aria-hidden') === 'true') return;

    refreshCssStickyLeftColumnSet(table, 'sticky-left', '--sticky-left', '--sticky-width');
    refreshCssStickyLeftColumnSet(table, 'sticky-left-mobile', '--sticky-mobile-left', '--sticky-mobile-width');
  }

  function refreshExternalStickyLeftColumns(table, options) {
    var api = window.YummyGuideAdministrateStickyLeftColumns;
    var settings = options || {};

    if (!api) return false;

    if (settings.columnId && typeof api.refreshColumnWidth === 'function') {
      return api.refreshColumnWidth({
        sourceTable: table,
        columnId: settings.columnId,
        width: settings.width
      });
    }

    if (typeof api.refreshTable === 'function') {
      return api.refreshTable(table);
    }

    return false;
  }

  function refreshTableWidthLayout(table, options) {
    refreshCssStickyLeftColumns(table);
    refreshExternalStickyLeftColumns(table, options);
    refreshStickyHeaderLayoutForTable(table);
  }

  function applyColumnWidth(columnId, width, scope) {
    allTrackedTables().forEach(function(table) {
      if (scope && storageScopeForTable(table) !== scope) return;
      if (!applyTableColumnWidth(table, columnId, width)) return;

      refreshTableWidthLayout(table, {
        columnId: columnId,
        width: width
      });
    });
  }

  function clearColumnWidth(columnId, scope) {
    allTrackedTables().forEach(function(table) {
      if (scope && storageScopeForTable(table) !== scope) return;
      if (!clearTableColumnWidth(table, columnId)) return;

      refreshTableWidthLayout(table);
    });
  }

  function sourceTableForHandle(handle) {
    var table = handle.closest(TABLE_SELECTOR);

    return table && table.getAttribute('aria-hidden') !== 'true' ? table : null;
  }

  function previewBoundsFromHeader(headerRect) {
    var viewportRight = viewportWidth();
    var viewportBottom = viewportHeight();
    var left = Math.max(0, Math.min(headerRect.left, viewportRight));
    var top = Math.max(0, Math.min(headerRect.top, viewportBottom));

    return {
      left: left,
      top: top,
      height: Math.max(32, viewportBottom - top),
      hiddenLeft: Math.max(0, left - headerRect.left),
      maxWidth: Math.max(0, viewportRight - left)
    };
  }

  function previewParentForTable(table) {
    return table.closest('.main-content, .admin-main') || document.body;
  }

  function updateDragPreview(preview, width) {
    if (!preview) return;

    preview.currentWidth = width;
    var visibleWidth = Math.max(0, width - preview.hiddenLeft);

    preview.element.style.width = cssPixelValue(Math.min(visibleWidth, preview.maxWidth));
  }

  function applyDragPreviewBounds(preview, bounds) {
    if (!preview || !bounds) return;

    preview.hiddenLeft = bounds.hiddenLeft;
    preview.maxWidth = bounds.maxWidth;
    preview.element.style.left = cssPixelValue(bounds.left);
    preview.element.style.top = cssPixelValue(bounds.top);
    preview.element.style.height = cssPixelValue(bounds.height);
    updateDragPreview(preview, preview.currentWidth);
  }

  function createDragPreview(table, header, width, headerRect) {
    var resolvedHeaderRect = headerRect || header.getBoundingClientRect();
    var bounds = previewBoundsFromHeader(resolvedHeaderRect);
    var element = document.createElement('div');

    element.className = PREVIEW_CLASS;
    element.setAttribute('aria-hidden', 'true');

    var preview = {
      element: element,
      hiddenLeft: bounds.hiddenLeft,
      maxWidth: bounds.maxWidth,
      currentWidth: width
    };

    applyDragPreviewBounds(preview, bounds);
    previewParentForTable(table).appendChild(element);

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

  function csrfToken() {
    var tokenElement = document.querySelector('meta[name="csrf-token"]');

    return tokenElement && tokenElement.getAttribute('content');
  }

  function persistPreference(payload) {
    var headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    var token = csrfToken();

    if (token) {
      headers['X-CSRF-Token'] = token;
    }

    window.fetch(PREFERENCES_ENDPOINT, {
      method: 'PATCH',
      credentials: 'same-origin',
      headers: headers,
      body: JSON.stringify(payload)
    }).catch(function(error) {
      if (window.console && window.console.warn) {
        window.console.warn('Failed to save admin column width preference', error);
      }
    });
  }

  function persistColumnWidth(scope, columnId, width) {
    persistPreference({
      preference: 'column_width',
      scope: scope,
      column_id: columnId,
      width: preciseNumber(width)
    });
  }

  function clearPersistedColumnWidth(scope, columnId) {
    persistPreference({
      preference: 'column_width',
      scope: scope,
      column_id: columnId,
      width: ''
    });
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
      applyColumnWidth(pendingWidth.columnId, pendingWidth.width, pendingWidth.storageScope);
      persistColumnWidth(pendingWidth.storageScope, pendingWidth.columnId, pendingWidth.width);
      window.requestAnimationFrame(function() {
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
      widthApplyFrame = null;
      applyPendingWidth(pendingWidth);
    });
  }

  function resizeGutterWidths() {
    var coarsePointer = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;

    return {
      left: coarsePointer ? COARSE_GUTTER_LEFT : DESKTOP_GUTTER_LEFT,
      right: coarsePointer ? COARSE_GUTTER_RIGHT : DESKTOP_GUTTER_RIGHT
    };
  }

  function eventInResizeGutter(event, rect) {
    if (!event || !rect) return false;

    var gutter = resizeGutterWidths();

    return event.clientX >= rect.right - gutter.left && event.clientX <= rect.right + gutter.right;
  }

  function resizeTargetFromEvent(event) {
    if (!event.target || !event.target.closest) return null;

    var header = event.target.closest(RESIZE_HEADER_SELECTOR);
    if (!header) return null;

    var rect = header.getBoundingClientRect();
    if (!eventInResizeGutter(event, rect)) return null;

    return {
      header: header,
      rect: rect
    };
  }

  function resizeHeaderFromEvent(event) {
    var target = resizeTargetFromEvent(event);

    return target && target.header;
  }

  function startDrag(event) {
    if (!pointerCanStartDrag(event)) return;
    if (applyingWidth || widthApplyFrame) return;

    var target = resizeTargetFromEvent(event);
    if (!target) return;

    var header = target.header;

    var columnId = headerColumnId(header);
    if (!columnId) return;

    var sourceTable = sourceTableForHandle(header);
    if (!sourceTable) return;

    var sourceHeader = columnHeader(sourceTable, columnId) || header;
    var handleRect = target.rect;
    var handleHeaderWidth = preciseNumber(handleRect.width || header.offsetWidth || 0);
    var sourceHeaderWidth = sourceHeader === header ? handleHeaderWidth : measuredWidth(sourceHeader);
    var startWidth = sourceHeaderWidth || handleHeaderWidth;
    if (!startWidth) return;
    var previewHeader = sourceHeaderWidth ? sourceHeader : header;
    var previewHeaderRect = previewHeader === header ? handleRect : null;

    event.preventDefault();
    event.stopPropagation();

    dragState = {
      columnId: columnId,
      storageScope: storageScopeForTable(sourceTable),
      startX: event.clientX,
      startWidth: startWidth,
      currentWidth: startWidth,
      pointerId: event.pointerId,
      handle: header,
      sourceTable: sourceTable,
      moved: false,
      preview: createDragPreview(sourceTable, previewHeader, startWidth, previewHeaderRect)
    };

    captureDragPointer(header, event);
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
      storageScope: dragState.storageScope,
      sourceTable: dragState.sourceTable,
      width: Math.max(MIN_WIDTH, dragState.currentWidth || dragState.startWidth),
      preview: dragState.preview
    };

    stopDragging(!shouldApplyWidth);
    if (!shouldApplyWidth) return;

    schedulePendingWidthApply(pendingWidth);
  }

  function resetColumn(event) {
    var header = resizeHeaderFromEvent(event);
    if (!header) return;

    var columnId = headerColumnId(header);
    if (!columnId) return;

    event.preventDefault();
    event.stopPropagation();
    cancelPendingWidthApply();
    stopDragging(true);

    var sourceTable = sourceTableForHandle(header);
    var scope = storageScopeForTable(sourceTable || header.closest(TABLE_SELECTOR));
    clearPersistedColumnWidth(scope, columnId);
    clearColumnWidth(columnId, scope);
    startApplyingWidth();

    window.requestAnimationFrame(function() {
      stopApplyingWidth(null);
    });
  }

  function stopResizeGutterClick(event) {
    if (!resizeHeaderFromEvent(event)) return;

    event.preventDefault();
    event.stopPropagation();
  }

  function initializeResizeEvents() {
    if (resizeEventsInitialized) return;

    resizeEventsInitialized = true;
    document.addEventListener('pointerdown', startDrag);
    document.addEventListener('dblclick', resetColumn);
    document.addEventListener('click', stopResizeGutterClick, true);
  }

  function initializeColumnResizer(root) {
    if (!root.querySelectorAll) return;

    initializeResizeEvents();
    tablesFromRoot(root).forEach(configureTable);
    refreshStickyHeaderLayout(root);
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
  window.addEventListener('resize', scheduleWindowResizeRefresh);

  window.YummyGuideAdministrateColumnResizer = {
    refreshStickyHeaderLayout: refreshStickyHeaderLayout
  };

})();
