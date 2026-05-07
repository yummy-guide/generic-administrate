(function() {
  var TABLE_SELECTOR = "table[data-fixed-columns-count]";
  var resizeObservers = new WeakMap();

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

  function resetStickyColumns(table) {
    table.querySelectorAll(".sticky-left").forEach(function(cell) {
      cell.classList.remove("sticky-left", "sticky-left--last");
      cell.style.removeProperty("left");
    });
  }

  function fixedColumnsCount(table) {
    var parsedCount = parseInt(table.dataset.fixedColumnsCount || "0", 10);
    return Number.isNaN(parsedCount) ? 0 : Math.max(parsedCount, 0);
  }

  function stickyOffsets(table, count) {
    var headerRow = table.querySelector("thead tr");
    if (!headerRow) return [];

    var widths = directCells(headerRow).slice(0, count).map(function(cell) {
      return measuredWidth(cell);
    });

    if (!widths.some(Boolean)) {
      Array.from(table.querySelectorAll("tbody tr, tfoot tr")).some(function(row) {
        var cells = directCells(row);
        if (cells.length < count || cells.some(function(cell) { return cell.colSpan > 1; })) return false;

        widths = cells.slice(0, count).map(function(cell) {
          return measuredWidth(cell);
        });
        return widths.some(Boolean);
      });
    }

    var offsets = [];
    var currentLeft = 0;

    widths.forEach(function(width) {
      offsets.push(currentLeft);
      currentLeft += width;
    });

    return offsets;
  }

  function applyStickyColumns(table) {
    resetStickyColumns(table);

    var count = fixedColumnsCount(table);
    if (count === 0) return;

    var offsets = stickyOffsets(table, count);
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

  function observeStickyColumns(table) {
    if (!window.ResizeObserver || resizeObservers.has(table)) return;

    var observer = new ResizeObserver(function() {
      window.requestAnimationFrame(function() {
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
