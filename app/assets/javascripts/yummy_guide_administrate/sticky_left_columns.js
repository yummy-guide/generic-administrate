(function() {
  var TABLE_SELECTOR = "table[data-fixed-columns-count]";
  var MOBILE_MEDIA_QUERY = "(max-width: 767px)";
  var resizeObservers = new WeakMap();
  var suppressedResizeTables = new WeakMap();

  function directCells(row) {
    return Array.from(row.children).filter(function(cell) {
      return cell.tagName === "TH" || cell.tagName === "TD";
    });
  }

  function preciseNumber(value) {
    return Math.round(value * 1000) / 1000;
  }

  function measuredWidth(element) {
    if (!element) return 0;

    var rectWidth = element.getBoundingClientRect().width;
    return preciseNumber(rectWidth || element.offsetWidth || 0);
  }

  function cssPixelValue(value) {
    return preciseNumber(value) + "px";
  }

  function headerColumnId(header) {
    return header.dataset.adminColumnResizerColumnId || header.dataset.columnId || "";
  }

  function columnIndex(headerCells, columnId) {
    if (!columnId) return -1;

    return headerCells.findIndex(function(header) {
      return headerColumnId(header) === columnId;
    });
  }

  function widthOverride(headerCells, options) {
    var settings = options || {};
    var width = parseFloat(settings.width);
    var index = columnIndex(headerCells, settings.columnId);

    if (index < 0 || Number.isNaN(width)) return null;

    return {
      index: index,
      width: preciseNumber(width)
    };
  }

  function applyWidthOverride(widths, override) {
    if (!override || override.index >= widths.length) return;

    widths[override.index] = override.width;
  }

  function resetStickyColumns(table) {
    table.querySelectorAll(".sticky-left").forEach(function(cell) {
      cell.classList.remove("sticky-left", "sticky-left--last");
      cell.style.removeProperty("left");
    });
  }

  function fixedColumnsCount(table) {
    var rawCount = table.dataset.fixedColumnsCount || "0";

    if (isMobile() && table.dataset.mobileFixedColumnsCount) {
      rawCount = table.dataset.mobileFixedColumnsCount;
    }

    var parsedCount = parseInt(rawCount, 10);
    return Number.isNaN(parsedCount) ? 0 : Math.max(parsedCount, 0);
  }

  function isMobile() {
    return window.matchMedia && window.matchMedia(MOBILE_MEDIA_QUERY).matches;
  }

  function stickyOffsets(table, count, options) {
    var headerRow = table.querySelector("thead tr");
    if (!headerRow) return [];

    var headerCells = directCells(headerRow);
    var override = widthOverride(headerCells, options);
    var widths = headerCells.slice(0, count).map(function(cell) {
      return measuredWidth(cell);
    });
    var hasMeasuredWidth = widths.some(Boolean);

    if (!hasMeasuredWidth) {
      Array.from(table.querySelectorAll("tbody tr, tfoot tr")).some(function(row) {
        var cells = directCells(row);
        if (cells.length < count || cells.some(function(cell) { return cell.colSpan > 1; })) return false;

        widths = cells.slice(0, count).map(function(cell) {
          return measuredWidth(cell);
        });
        return widths.some(Boolean);
      });
    }

    applyWidthOverride(widths, override);

    var offsets = [];
    var currentLeft = 0;

    widths.forEach(function(width) {
      offsets.push(currentLeft);
      currentLeft += width;
    });

    return offsets;
  }

  function applyStickyColumns(table, options) {
    resetStickyColumns(table);

    var count = fixedColumnsCount(table);
    if (count === 0) return;

    var offsets = stickyOffsets(table, count, options);
    if (offsets.length === 0) return;

    table.querySelectorAll("thead tr, tbody tr, tfoot tr").forEach(function(row) {
      var cells = directCells(row);
      if (cells.length === 0 || cells.some(function(cell) { return cell.colSpan > 1; })) return;

      cells.slice(0, offsets.length).forEach(function(cell, index) {
        cell.classList.add("sticky-left");
        if (index === offsets.length - 1) {
          cell.classList.add("sticky-left--last");
        }
        cell.style.left = cssPixelValue(offsets[index]);
      });
    });
  }

  function suppressResizeApply(table) {
    if (!table) return;

    var token = (suppressedResizeTables.get(table) || 0) + 1;
    suppressedResizeTables.set(table, token);

    window.setTimeout(function() {
      if (suppressedResizeTables.get(table) === token) {
        suppressedResizeTables.delete(table);
      }
    }, 250);
  }

  function resizeApplySuppressed(table) {
    return suppressedResizeTables.has(table);
  }

  function refreshTable(table) {
    if (!table) return false;

    suppressResizeApply(table);
    applyStickyColumns(table);

    return true;
  }

  function refreshColumnWidth(options) {
    var settings = options || {};
    var table = settings.sourceTable;

    if (!table) return false;

    suppressResizeApply(table);
    applyStickyColumns(table, {
      columnId: settings.columnId,
      width: settings.width
    });

    return true;
  }

  function observeStickyColumns(table) {
    if (!window.ResizeObserver || resizeObservers.has(table)) return;

    var observer = new ResizeObserver(function() {
      if (resizeApplySuppressed(table)) return;

      window.requestAnimationFrame(function() {
        if (resizeApplySuppressed(table)) return;

        applyStickyColumns(table);
      });
    });

    observer.observe(table);
    if (table.parentElement) {
      observer.observe(table.parentElement);
    }

    resizeObservers.set(table, observer);
  }

  function initializeStickyColumns(root) {
    var tables = [];

    if (root.matches && root.matches(TABLE_SELECTOR)) {
      tables.push(root);
    }

    if (root.querySelectorAll) {
      root.querySelectorAll(TABLE_SELECTOR).forEach(function(table) {
        tables.push(table);
      });
    }

    tables.forEach(function(table) {
      applyStickyColumns(table);
      observeStickyColumns(table);
    });
  }

  function initializeFromDocument() {
    initializeStickyColumns(document);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeFromDocument);
  } else {
    initializeFromDocument();
  }

  document.addEventListener("turbo:load", initializeFromDocument);
  window.addEventListener("resize", initializeFromDocument);

  window.YummyGuideAdministrateStickyLeftColumns = {
    refreshColumnWidth: refreshColumnWidth,
    refreshTable: refreshTable
  };

  if (window.MutationObserver) {
    var mutationObserver = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            initializeStickyColumns(node);
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
