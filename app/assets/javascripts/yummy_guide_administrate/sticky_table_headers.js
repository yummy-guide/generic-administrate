(function() {
  var TABLE_SELECTOR = 'table[data-fixed-columns-count]';
  var WRAPPER_SELECTOR = '[data-fixed-header-scroll], .scroll-table, .home-table__wrapper, .table-wrap, .af__table__content';
  var resizeObservers = new WeakMap();
  var observedScrolls = new WeakMap();
  var scrollSyncStates = new WeakMap();

  function directCells(row) {
    return Array.from(row.children).filter(function(cell) {
      return cell.tagName === 'TH' || cell.tagName === 'TD';
    });
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

  function measuredTableWidth(table, widths) {
    var widthsSum = preciseNumber(widths.reduce(function(total, width) {
      return total + width;
    }, 0));

    return preciseNumber(Math.max(table.scrollWidth || 0, measuredWidth(table), widthsSum));
  }

  function fixedColumnsCount(table) {
    var parsedCount = parseInt(table.dataset.fixedColumnsCount || '0', 10);
    return Number.isNaN(parsedCount) ? 0 : Math.max(parsedCount, 0);
  }

  function stickyOffsets(widths) {
    var offsets = [];
    var currentLeft = 0;

    widths.forEach(function(width) {
      offsets.push(currentLeft);
      currentLeft += width;
    });

    return offsets;
  }

  function isVisible(element) {
    if (!element) return false;

    var styles = window.getComputedStyle(element);
    return styles.display !== 'none' && styles.visibility !== 'hidden' && element.getClientRects().length > 0;
  }

  function trackedTablesInWrapper(scroll) {
    return Array.from(scroll.querySelectorAll(TABLE_SELECTOR)).filter(function(table) {
      return table.getAttribute('aria-hidden') !== 'true' && !table.classList.contains('table-fixed-header__table');
    });
  }

  function isSourceTableCandidate(table) {
    return table.getAttribute('aria-hidden') !== 'true' &&
      !table.classList.contains('table-fixed-header__table') &&
      !table.closest('[data-fixed-table-header]');
  }

  function activeSourceTable(scroll) {
    var tables = trackedTablesInWrapper(scroll);

    return tables.find(isVisible) || tables[0] || null;
  }

  function ensureScrollWrapper(table) {
    var existingWrapper = table.closest(WRAPPER_SELECTOR);

    if (existingWrapper) {
      existingWrapper.setAttribute('data-fixed-header-scroll', '');
      if (!existingWrapper.classList.contains('home-table__wrapper')) {
        existingWrapper.classList.add('sticky-table-scroll');
      }
      return existingWrapper;
    }

    var wrapper = document.createElement('div');
    wrapper.className = 'scroll-table sticky-table-scroll';
    wrapper.setAttribute('data-fixed-header-scroll', '');
    table.parentNode.insertBefore(wrapper, table);
    wrapper.appendChild(table);

    return wrapper;
  }

  function autoFixedHeaderSlot(scroll) {
    var sibling = scroll.previousElementSibling;
    if (!sibling || !sibling.hasAttribute('data-auto-fixed-table-header')) return null;

    return sibling;
  }

  function explicitFixedHeaderSlot(scroll) {
    var mainContent = scroll.closest('.main-content');
    if (!mainContent) return null;

    return Array.from(mainContent.querySelectorAll('[data-fixed-table-header]')).find(function(slot) {
      return !slot.hasAttribute('data-auto-fixed-table-header');
    }) || null;
  }

  function prepareFixedHeaderSlot(slot, inline) {
    slot.classList.add('table-fixed-header-slot');

    if (inline) {
      slot.setAttribute('data-fixed-header-inline', 'true');
    } else {
      slot.removeAttribute('data-fixed-header-inline');
    }
  }

  function numericPixelValue(value) {
    var parsedValue = parseFloat(value || '0');
    return Number.isNaN(parsedValue) ? 0 : parsedValue;
  }

  function syncAutoSlotGap(slot) {
    if (!slot) return;

    if (!slot.hasAttribute('data-auto-fixed-table-header')) {
      slot.style.removeProperty('margin-bottom');
      return;
    }

    var parent = slot.parentElement;
    if (!parent) return;

    var parentStyles = window.getComputedStyle(parent);
    var isColumnFlex = parentStyles.display === 'flex' && parentStyles.flexDirection.indexOf('column') === 0;
    var isGrid = parentStyles.display === 'grid';
    var gap = numericPixelValue(parentStyles.rowGap || parentStyles.gap);

    if ((isColumnFlex || isGrid) && gap > 0) {
      slot.style.marginBottom = cssPixelValue(-gap);
      return;
    }

    slot.style.removeProperty('margin-bottom');
  }

  function ensureFixedHeaderScrollViewport(slot) {
    var fixedScroll = slot.querySelector('.table-fixed-header__scroll');

    if (fixedScroll) return fixedScroll;

    fixedScroll = document.createElement('div');
    fixedScroll.className = 'table-fixed-header__scroll';
    slot.innerHTML = '';
    slot.appendChild(fixedScroll);

    return fixedScroll;
  }

  function ensureFixedHeaderSpacer(fixedScroll) {
    var spacer = fixedScroll.querySelector('.table-fixed-header__spacer');

    if (spacer) return spacer;

    spacer = document.createElement('div');
    spacer.className = 'table-fixed-header__spacer';
    spacer.setAttribute('aria-hidden', 'true');
    fixedScroll.appendChild(spacer);

    return spacer;
  }

  function ensureFixedHeaderSlot(scroll) {
    var explicitSlot = explicitFixedHeaderSlot(scroll);
    if (explicitSlot) {
      prepareFixedHeaderSlot(explicitSlot, true);
      return explicitSlot;
    }

    var autoSlot = autoFixedHeaderSlot(scroll);
    if (autoSlot) {
      prepareFixedHeaderSlot(autoSlot, false);
      return autoSlot;
    }

    autoSlot = document.createElement('div');
    autoSlot.className = 'table-fixed-header-slot';
    autoSlot.setAttribute('data-fixed-table-header', '');
    autoSlot.setAttribute('data-auto-fixed-table-header', 'true');
    autoSlot.hidden = true;
    scroll.parentNode.insertBefore(autoSlot, scroll);

    return autoSlot;
  }

  function closestMainContentHeader(scroll) {
    var mainContent = scroll.closest('.main-content');
    if (!mainContent) return null;

    return mainContent.querySelector('.main-content__header');
  }

  function syncStickyPageHeader(scroll, slot) {
    var header = closestMainContentHeader(scroll);
    if (!header) {
      slot.style.top = '0px';
      syncAutoSlotGap(slot);
      return;
    }

    if (!header.classList.contains('reservations-list-header')) {
      header.classList.add('main-content__header--sticky-table-layout');
    }

    if (slot.hasAttribute('data-auto-fixed-table-header')) {
      slot.style.top = Math.ceil(header.getBoundingClientRect().height) + 'px';
    } else {
      slot.style.top = '0px';
    }

    syncAutoSlotGap(slot);
  }

  function syncFixedHeaderScroll(scroll, fixedScroll, scrollLeft) {
    if (!scroll || !fixedScroll) return;

    var left = typeof scrollLeft === 'number' ? scrollLeft : scroll.scrollLeft;

    fixedScroll.scrollLeft = left;
  }

  function fixedHeaderTableClassName(sourceTable) {
    var excludedClasses = {
      'table-with-fixed-header': true,
      'home-table--with-fixed-header': true,
      'table-fixed-header__table': true,
      'home-table--fixed-header': true
    };

    var classes = sourceTable.className ? sourceTable.className.split(/\s+/).filter(function(className) {
      return className && !excludedClasses[className];
    }) : [];

    classes.push('table-fixed-header__table');
    if (sourceTable.classList.contains('home-table')) {
      classes.push('home-table--fixed-header');
    }

    return Array.from(new Set(classes)).join(' ');
  }

  function applyColGroup(table, widths) {
    if (!table || !widths.length) return;

    var colgroup = table.querySelector('colgroup[data-fixed-header-colgroup]');

    if (!colgroup) {
      colgroup = document.createElement('colgroup');
      colgroup.setAttribute('data-fixed-header-colgroup', 'true');
      table.insertBefore(colgroup, table.firstChild);
    }

    colgroup.innerHTML = '';

    widths.forEach(function(width) {
      var col = document.createElement('col');
      col.style.width = cssPixelValue(width);
      colgroup.appendChild(col);
    });
  }

  function applyFixedHeaderCellWidths(fixedTable, widths) {
    var headerRow = fixedTable && fixedTable.querySelector('thead tr');
    if (!headerRow) return;

    directCells(headerRow).forEach(function(cell, index) {
      var width = widths[index];
      if (!width) {
        cell.style.removeProperty('width');
        cell.style.removeProperty('min-width');
        return;
      }

      cell.style.width = cssPixelValue(width);
      cell.style.minWidth = cssPixelValue(width);
    });
  }

  function widthCandidateRows(sourceTable, headerCellCount) {
    var candidates = [];
    var headerRow = sourceTable.querySelector('thead tr');

    if (headerRow) {
      candidates.push(headerRow);
    }

    Array.from(sourceTable.querySelectorAll('tbody tr, tfoot tr')).forEach(function(row) {
      var cells = directCells(row);
      if (cells.length !== headerCellCount || cells.some(function(cell) { return cell.colSpan > 1; })) return;

      candidates.push(row);
    });

    return candidates;
  }

  function hasMeasurableDataRow(sourceTable, headerCellCount) {
    return Array.from(sourceTable.querySelectorAll('tbody tr, tfoot tr')).some(function(row) {
      var cells = directCells(row);
      return cells.length === headerCellCount && !cells.some(function(cell) { return cell.colSpan > 1; });
    });
  }

  function removeGeneratedColGroup(table) {
    if (!table) return;

    var colgroup = table.querySelector('colgroup[data-fixed-header-colgroup]');
    if (colgroup) {
      colgroup.remove();
    }
  }

  function generatedColGroupWidths(table, expectedCount) {
    if (!table) return [];

    var colgroup = table.querySelector('colgroup[data-fixed-header-colgroup]');
    if (!colgroup) return [];

    var widths = Array.from(colgroup.children).map(function(col) {
      var inlineWidth = parseFloat(col.style.width || '0');
      return Number.isNaN(inlineWidth) ? 0 : preciseNumber(inlineWidth);
    });

    if (expectedCount && widths.length !== expectedCount) return [];

    return widths;
  }

  function clearFixedHeaderState(slot, scroll, sourceTable) {
    if (slot) {
      slot.hidden = true;
    }

    if (!sourceTable) return;

    removeGeneratedColGroup(sourceTable);
    sourceTable.classList.remove('table-with-fixed-header');

    if (sourceTable.classList.contains('home-table')) {
      sourceTable.classList.remove('home-table--with-fixed-header');

      if (scroll) {
        scroll.classList.remove('home-table__wrapper--fixed-header-ready');
      }
    }
  }

  function measuredColumnWidths(sourceTable, fixedTable, options) {
    var settings = options || {};
    var sourceHead = sourceTable.querySelector('thead');
    var sourceRow = sourceHead && sourceHead.querySelector('tr');

    if (!sourceRow) return [];

    var headerCells = directCells(sourceRow);
    var widths = headerCells.map(function() { return 0; });

    widthCandidateRows(sourceTable, headerCells.length).forEach(function(row) {
      directCells(row).forEach(function(cell, index) {
        widths[index] = Math.max(widths[index], measuredWidth(cell));
      });
    });

    if (!widths.some(Boolean)) {
      var generatedWidths = generatedColGroupWidths(sourceTable, headerCells.length);
      if (generatedWidths.length) {
        widths = generatedWidths.slice();
      }
    }

    if (!widths.some(Boolean) && fixedTable && settings.allowFixedTableFallback !== false) {
      var fixedRow = fixedTable.querySelector('thead tr');
      var fixedCells = fixedRow ? directCells(fixedRow) : [];

      fixedCells.forEach(function(cell, index) {
        widths[index] = Math.max(widths[index] || 0, measuredWidth(cell));
      });
    }

    return widths;
  }

  function applyFixedHeaderStickyColumns(sourceTable, fixedTable, widths) {
    var headerRow = fixedTable.querySelector('thead tr');
    if (!headerRow) return;

    directCells(headerRow).forEach(function(cell) {
      cell.classList.remove('sticky-left', 'sticky-left--last');
      cell.style.removeProperty('left');
    });

    var count = fixedColumnsCount(sourceTable);
    if (count === 0) return;

    var offsets = stickyOffsets(widths.slice(0, count));

    directCells(headerRow).slice(0, offsets.length).forEach(function(cell, index) {
      cell.classList.add('sticky-left');
      if (index === offsets.length - 1) {
        cell.classList.add('sticky-left--last');
      }
      cell.style.left = cssPixelValue(offsets[index]);
    });
  }

  function buildFixedTableHeader(slot, scroll, sourceTable) {
    if (!slot || !scroll || !sourceTable) return;

    var sourceHead = sourceTable.querySelector('thead');
    if (!sourceHead) {
      clearFixedHeaderState(slot, scroll, sourceTable);
      return;
    }

    var sourceRow = sourceHead.querySelector('tr');
    var headerCells = sourceRow ? directCells(sourceRow) : [];
    var hasDataRow = hasMeasurableDataRow(sourceTable, headerCells.length);

    if (!headerCells.length) {
      clearFixedHeaderState(slot, scroll, sourceTable);
      return;
    }

    var fixedScroll = ensureFixedHeaderScrollViewport(slot);
    var fixedTable = fixedScroll.querySelector('.table-fixed-header__table');
    var fixedSpacer = ensureFixedHeaderSpacer(fixedScroll);

    if (!fixedTable) {
      fixedTable = document.createElement('table');
      fixedTable.setAttribute('aria-hidden', 'true');
    }

    fixedTable.className = fixedHeaderTableClassName(sourceTable);
    fixedTable.dataset.fixedColumnsCount = sourceTable.dataset.fixedColumnsCount || '0';
    fixedTable.innerHTML = sourceHead.outerHTML;

    if (fixedTable.parentNode !== fixedScroll) {
      fixedScroll.innerHTML = '';
      fixedScroll.appendChild(fixedTable);
      fixedScroll.appendChild(fixedSpacer);
    }

    var widths = measuredColumnWidths(sourceTable, fixedTable, {
      allowFixedTableFallback: hasDataRow
    });
    if (!widths.some(Boolean)) {
      clearFixedHeaderState(slot, scroll, sourceTable);
      return;
    }

    applyColGroup(sourceTable, widths);
    applyColGroup(fixedTable, widths);
    applyFixedHeaderCellWidths(fixedTable, widths);
    applyFixedHeaderStickyColumns(sourceTable, fixedTable, widths);

    var fixedScrollWidth = measuredTableWidth(sourceTable, widths);

    fixedTable.style.transform = '';
    fixedTable.style.marginLeft = '';
    fixedTable.style.width = cssPixelValue(fixedScrollWidth);
    fixedSpacer.style.width = '0px';
    fixedSpacer.style.minWidth = '0px';
    syncStickyPageHeader(scroll, slot);
    syncFixedHeaderScroll(scroll, fixedScroll);

    sourceTable.classList.add('table-with-fixed-header');
    if (sourceTable.classList.contains('home-table')) {
      sourceTable.classList.add('home-table--with-fixed-header');
      scroll.classList.add('home-table__wrapper--fixed-header-ready');
    }

    slot.hidden = false;
  }

  function observeFixedHeader(scroll) {
    if (!window.ResizeObserver) return;

    var observer = resizeObservers.get(scroll);
    if (!observer) {
      observer = new ResizeObserver(function() {
        window.requestAnimationFrame(function() {
          initializeFixedHeaderForScroll(scroll);
        });
      });
      observer.observe(scroll);
      resizeObservers.set(scroll, observer);
    }

    trackedTablesInWrapper(scroll).forEach(function(table) {
      observer.observe(table);
    });
  }

  function observeFixedHeaderScroll(scroll) {
    if (observedScrolls.has(scroll)) return;

    scroll.addEventListener('scroll', function() {
      var state = scrollSyncStates.get(scroll) || {};
      state.scrollLeft = scroll.scrollLeft;

      if (state.frame) return;

      state.frame = window.requestAnimationFrame(function() {
        var slot = ensureFixedHeaderSlot(scroll);
        state.frame = null;
        syncFixedHeaderScroll(scroll, slot.querySelector('.table-fixed-header__scroll'), state.scrollLeft);
      });

      scrollSyncStates.set(scroll, state);
    }, { passive: true });

    observedScrolls.set(scroll, true);
  }

  function initializeFixedHeaderForScroll(scroll) {
    var sourceTable = activeSourceTable(scroll);
    if (!sourceTable) return;

    var slot = ensureFixedHeaderSlot(scroll);
    buildFixedTableHeader(slot, scroll, sourceTable);
    observeFixedHeader(scroll);
    observeFixedHeaderScroll(scroll);
  }

  function initializeFixedHeaders(root) {
    var tables = [];
    var scrolls = [];

    if (root.matches && root.matches(TABLE_SELECTOR)) {
      if (isSourceTableCandidate(root)) {
        tables.push(root);
      }
    }

    if (root.querySelectorAll) {
      root.querySelectorAll(TABLE_SELECTOR).forEach(function(table) {
        if (isSourceTableCandidate(table)) {
          tables.push(table);
        }
      });
    }

    tables.forEach(function(table) {
      var scroll = ensureScrollWrapper(table);
      if (scrolls.indexOf(scroll) === -1) {
        scrolls.push(scroll);
      }
    });

    scrolls.forEach(function(scroll) {
      initializeFixedHeaderForScroll(scroll);
    });
  }

  function initializeFromDocument() {
    initializeFixedHeaders(document);
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
          if (node.nodeType === Node.ELEMENT_NODE) {
            initializeFixedHeaders(node);
          }
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
