(function() {
  var TRIGGER_SELECTOR = "[data-admin-tooltip-trigger='true']";
  var TOOLTIP_ID = "admin-tooltip";
  var TOOLTIP_CLASS = "admin-tooltip";
  var VISIBLE_CLASS = "admin-tooltip--visible";
  var MOBILE_MEDIA_QUERY = "(max-width: 767px)";
  var EDGE_GAP = 8;
  var OFFSET = 8;
  var activeTrigger = null;
  var hoveredTrigger = null;
  var focusedTrigger = null;
  var tooltipElement = null;

  function isMobile() {
    return window.matchMedia && window.matchMedia(MOBILE_MEDIA_QUERY).matches;
  }

  function closestTrigger(target) {
    if (!target || !target.closest) return null;

    return target.closest(TRIGGER_SELECTOR);
  }

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  function getTooltipElement() {
    if (tooltipElement) return tooltipElement;

    tooltipElement = document.createElement("div");
    tooltipElement.id = TOOLTIP_ID;
    tooltipElement.className = TOOLTIP_CLASS;
    tooltipElement.setAttribute("role", "tooltip");
    document.body.appendChild(tooltipElement);

    return tooltipElement;
  }

  function tooltipContent(trigger) {
    var contentId = trigger.getAttribute("data-admin-tooltip-content-id");
    var template = contentId ? document.getElementById(contentId) : null;
    if (template) {
      return {
        html: template.innerHTML,
        text: ""
      };
    }

    var text = trigger.getAttribute("data-admin-tooltip-text") || "";
    return {
      html: "",
      text: text.trim() ? text : ""
    };
  }

  function setTriggerState(trigger, expanded) {
    if (!trigger) return;

    trigger.setAttribute("aria-expanded", expanded ? "true" : "false");

    if (expanded) {
      trigger.setAttribute("aria-describedby", TOOLTIP_ID);
    } else {
      trigger.removeAttribute("aria-describedby");
    }
  }

  function positionTooltip() {
    if (!activeTrigger || !tooltipElement || !tooltipElement.classList.contains(VISIBLE_CLASS)) return;

    var targetRect = activeTrigger.getBoundingClientRect();
    tooltipElement.style.left = "0px";
    tooltipElement.style.top = "0px";

    var tooltipRect = tooltipElement.getBoundingClientRect();
    var viewportWidth = document.documentElement.clientWidth || window.innerWidth;
    var viewportHeight = document.documentElement.clientHeight || window.innerHeight;
    var top = targetRect.top - tooltipRect.height - OFFSET;
    var placement = "top";

    if (top < EDGE_GAP) {
      top = targetRect.bottom + OFFSET;
      placement = "bottom";
    }

    top = clamp(top, EDGE_GAP, Math.max(EDGE_GAP, viewportHeight - tooltipRect.height - EDGE_GAP));

    var left = targetRect.left + (targetRect.width / 2) - (tooltipRect.width / 2);
    left = clamp(left, EDGE_GAP, Math.max(EDGE_GAP, viewportWidth - tooltipRect.width - EDGE_GAP));

    var arrowMax = Math.max(10, tooltipRect.width - 10);
    var arrowLeft = clamp(targetRect.left + (targetRect.width / 2) - left - 4, 10, arrowMax);

    tooltipElement.style.left = Math.round(left) + "px";
    tooltipElement.style.top = Math.round(top) + "px";
    tooltipElement.style.setProperty("--admin-tooltip-arrow-left", Math.round(arrowLeft) + "px");
    tooltipElement.setAttribute("data-admin-tooltip-placement", placement);
  }

  function showTooltip(trigger) {
    var content = tooltipContent(trigger);
    if (!content.html && !content.text) return;

    if (activeTrigger && activeTrigger !== trigger) {
      hideTooltip();
    }

    activeTrigger = trigger;
    tooltipElement = getTooltipElement();
    if (content.html) {
      tooltipElement.innerHTML = content.html;
    } else {
      tooltipElement.textContent = content.text;
    }
    tooltipElement.classList.add(VISIBLE_CLASS);
    setTriggerState(trigger, true);

    if (window.requestAnimationFrame) {
      window.requestAnimationFrame(positionTooltip);
    } else {
      positionTooltip();
    }
  }

  function hideTooltip(trigger) {
    if (trigger && activeTrigger !== trigger) return;

    setTriggerState(activeTrigger, false);

    if (tooltipElement) {
      tooltipElement.classList.remove(VISIBLE_CLASS);
    }

    activeTrigger = null;
  }

  function toggleTooltip(trigger) {
    if (activeTrigger === trigger && tooltipElement && tooltipElement.classList.contains(VISIBLE_CLASS)) {
      hideTooltip(trigger);
      return;
    }

    showTooltip(trigger);
  }

  document.addEventListener("mouseover", function(event) {
    var trigger = closestTrigger(event.target);
    if (!trigger || isMobile() || (event.relatedTarget && trigger.contains(event.relatedTarget))) return;

    hoveredTrigger = trigger;
    showTooltip(trigger);
  });

  document.addEventListener("mouseout", function(event) {
    var trigger = closestTrigger(event.target);
    if (!trigger || isMobile() || (event.relatedTarget && trigger.contains(event.relatedTarget))) return;

    if (hoveredTrigger === trigger) {
      hoveredTrigger = null;
    }
    if (focusedTrigger === trigger) return;

    hideTooltip(trigger);
  });

  document.addEventListener("focusin", function(event) {
    var trigger = closestTrigger(event.target);
    if (!trigger || isMobile()) return;

    focusedTrigger = trigger;
    showTooltip(trigger);
  });

  document.addEventListener("focusout", function(event) {
    var trigger = closestTrigger(event.target);
    if (!trigger || isMobile()) return;

    if (focusedTrigger === trigger) {
      focusedTrigger = null;
    }
    if (hoveredTrigger === trigger) return;

    hideTooltip(trigger);
  });

  document.addEventListener("click", function(event) {
    var trigger = closestTrigger(event.target);

    if (trigger) {
      if (!isMobile()) return;

      event.preventDefault();
      event.stopPropagation();
      toggleTooltip(trigger);
      return;
    }

    if (activeTrigger && isMobile()) {
      hideTooltip();
    }
  });

  document.addEventListener("keydown", function(event) {
    if (event.key !== "Escape") return;

    hideTooltip();
  });

  window.addEventListener("scroll", positionTooltip, true);
  window.addEventListener("resize", function() {
    hideTooltip();
  });
})();
