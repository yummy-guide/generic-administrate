(function() {
  var STORAGE_KEY = "yummyGuideAdministrate.navigationWidthPx";
  var LEGACY_STORAGE_KEYS = ["wowTokyo.adminNavigationWidthPx"];
  var WIDTH_VARIABLE = "--admin-navigation-width";
  var NAVIGATION_SELECTOR = ".app-container > .navigation, body.admin-body > aside";
  var HANDLE_CLASS = "admin-navigation-resize-handle";
  var SCROLL_AREA_CLASS = "admin-navigation-scroll-area";
  var TOOLTIP_CLASS = "admin-navigation-tooltip";
  var TOOLTIP_VISIBLE_CLASS = "admin-navigation-tooltip--visible";
  var RESIZING_BODY_CLASS = "admin-navigation-is-resizing";
  var RESIZING_NAVIGATION_CLASS = "admin-navigation--resizing";
  var DESKTOP_MEDIA_QUERY = "(min-width: 768px)";
  var MIN_WIDTH_PX = 25;
  var MAX_WIDTH_PX = 250;

  function ready(callback) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", callback, { once: true });
      return;
    }

    callback();
  }

  function toArray(nodeList) {
    return Array.prototype.slice.call(nodeList || []);
  }

  function isDesktop() {
    return window.matchMedia(DESKTOP_MEDIA_QUERY).matches;
  }

  function parseStoredWidth(value) {
    if (!value) return null;

    var width = parseFloat(value);
    return Number.isFinite(width) ? width : null;
  }

  function storedWidthForKey(key) {
    try {
      return parseStoredWidth(window.localStorage.getItem(key));
    } catch (_error) {
      return null;
    }
  }

  function readStoredWidth() {
    var width = storedWidthForKey(STORAGE_KEY);
    if (width !== null) return width;

    for (var index = 0; index < LEGACY_STORAGE_KEYS.length; index += 1) {
      width = storedWidthForKey(LEGACY_STORAGE_KEYS[index]);
      if (width !== null) return width;
    }

    return null;
  }

  function saveWidth(width) {
    try {
      window.localStorage.setItem(STORAGE_KEY, Math.round(width) + "px");
    } catch (_error) {
      // localStorage may be unavailable in private browsing or restricted contexts.
    }
  }

  function clampWidth(width) {
    return Math.min(Math.max(width, MIN_WIDTH_PX), MAX_WIDTH_PX);
  }

  function applyWidth(width, body) {
    var clampedWidth = clampWidth(width);
    body.style.setProperty(WIDTH_VARIABLE, Math.round(clampedWidth) + "px");

    return clampedWidth;
  }

  function applyStoredWidth(body) {
    var storedWidth = readStoredWidth();
    if (storedWidth === null) return null;

    return applyWidth(storedWidth, body);
  }

  function resizeWidthFromPointer(event, body, navigation) {
    var navigationLeft = navigation.getBoundingClientRect().left;
    return applyWidth(event.clientX - navigationLeft, body);
  }

  function childWithClass(element, className) {
    return toArray(element.children).find(function(child) {
      return child.classList.contains(className);
    });
  }

  function setupNavigationScrollArea(navigation) {
    var existingScrollArea = childWithClass(navigation, SCROLL_AREA_CLASS);
    if (existingScrollArea) return existingScrollArea;

    var scrollArea = document.createElement("div");
    var handle = childWithClass(navigation, HANDLE_CLASS);

    scrollArea.className = SCROLL_AREA_CLASS;
    toArray(navigation.childNodes).forEach(function(node) {
      if (node === handle) return;
      scrollArea.appendChild(node);
    });
    navigation.insertBefore(scrollArea, handle || null);

    return scrollArea;
  }

  function setupNavigationTooltips(container) {
    var tooltipTargets = toArray(container.querySelectorAll("a, button"));
    if (tooltipTargets.length === 0) return;

    var tooltip = document.createElement("div");
    var activeTarget = null;

    tooltip.className = TOOLTIP_CLASS;
    tooltip.setAttribute("role", "tooltip");
    document.body.appendChild(tooltip);

    function hideTooltip() {
      tooltip.classList.remove(TOOLTIP_VISIBLE_CLASS);
      activeTarget = null;
    }

    function positionTooltip() {
      if (!activeTarget || !isDesktop()) {
        hideTooltip();
        return;
      }

      var targetRect = activeTarget.getBoundingClientRect();
      var tooltipRect = tooltip.getBoundingClientRect();
      var top = Math.min(
        Math.max(targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2), 8),
        window.innerHeight - tooltipRect.height - 8
      );
      var left = Math.min(targetRect.right + 8, window.innerWidth - tooltipRect.width - 8);

      tooltip.style.left = Math.max(left, 8) + "px";
      tooltip.style.top = top + "px";
    }

    function showTooltip(target) {
      var label = target.textContent.trim();
      if (!label || !isDesktop()) return;

      activeTarget = target;
      tooltip.textContent = label;
      tooltip.classList.add(TOOLTIP_VISIBLE_CLASS);
      positionTooltip();
    }

    tooltipTargets.forEach(function(target) {
      target.addEventListener("mouseenter", function() {
        showTooltip(target);
      });
      target.addEventListener("mouseleave", hideTooltip);
      target.addEventListener("focus", function() {
        showTooltip(target);
      });
      target.addEventListener("blur", hideTooltip);
    });

    window.addEventListener("resize", positionTooltip);
    window.addEventListener("scroll", positionTooltip, true);
  }

  function addResizeHandle(body, navigation) {
    if (navigation.querySelector("." + HANDLE_CLASS)) return;

    var handle = document.createElement("div");
    var latestWidth = null;

    handle.className = HANDLE_CLASS;
    handle.setAttribute("role", "separator");
    handle.setAttribute("aria-orientation", "vertical");
    handle.setAttribute("aria-label", "Resize navigation");
    navigation.appendChild(handle);

    handle.addEventListener("pointerdown", function(event) {
      if (!isDesktop() || (event.pointerType === "mouse" && event.button !== 0)) return;

      event.preventDefault();
      latestWidth = navigation.getBoundingClientRect().width;
      body.classList.add(RESIZING_BODY_CLASS);
      navigation.classList.add(RESIZING_NAVIGATION_CLASS);
      handle.setPointerCapture(event.pointerId);

      function onPointerMove(moveEvent) {
        latestWidth = resizeWidthFromPointer(moveEvent, body, navigation);
      }

      function stopResize() {
        document.removeEventListener("pointermove", onPointerMove);
        document.removeEventListener("pointerup", stopResize);
        document.removeEventListener("pointercancel", stopResize);
        body.classList.remove(RESIZING_BODY_CLASS);
        navigation.classList.remove(RESIZING_NAVIGATION_CLASS);

        if (latestWidth !== null) saveWidth(latestWidth);
        latestWidth = null;
      }

      document.addEventListener("pointermove", onPointerMove);
      document.addEventListener("pointerup", stopResize);
      document.addEventListener("pointercancel", stopResize);
    });
  }

  function setupResizableNavigation() {
    var body = document.querySelector("body.admin-body") || document.body;
    var navigation = document.querySelector(NAVIGATION_SELECTOR);
    var scrollArea = null;
    var resizeAnimationFrame = null;

    if (!body || !navigation || navigation.dataset.resizableNavigationInitialized === "true") return;

    navigation.dataset.resizableNavigationInitialized = "true";
    applyStoredWidth(body);
    scrollArea = setupNavigationScrollArea(navigation);
    setupNavigationTooltips(scrollArea);
    addResizeHandle(body, navigation);

    window.addEventListener("resize", function() {
      if (resizeAnimationFrame) {
        window.cancelAnimationFrame(resizeAnimationFrame);
      }

      resizeAnimationFrame = window.requestAnimationFrame(function() {
        applyStoredWidth(body);
        resizeAnimationFrame = null;
      });
    });
  }

  ready(setupResizableNavigation);
})();
