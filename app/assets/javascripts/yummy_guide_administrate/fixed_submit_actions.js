(function() {
  var ACTION_SELECTOR = ".form-actions, .form_submit";
  var EXPLICIT_ACTION_SELECTOR = '[data-fixed-submit-actions="true"]';
  var SUBMIT_SELECTOR = 'input[type="submit"], button[type="submit"], button.async-form__submit';
  var scheduled = false;
  var bar = null;
  var barActions = null;
  var observedAction = null;
  var observer = null;

  function toArray(nodeList) {
    return Array.prototype.slice.call(nodeList || []);
  }

  function matchesSelector(element, selector) {
    if (!element || element.nodeType !== 1) return false;

    var proto = Element.prototype;
    var matcher = proto.matches || proto.msMatchesSelector || proto.webkitMatchesSelector;
    return matcher ? matcher.call(element, selector) : false;
  }

  function closest(element, selector) {
    var current = element;

    while (current && current.nodeType === 1) {
      if (matchesSelector(current, selector)) return current;
      current = current.parentElement;
    }

    return null;
  }

  function isVisible(element) {
    if (!element) return false;

    var styles = window.getComputedStyle(element);
    return styles.display !== "none" &&
      styles.visibility !== "hidden" &&
      element.getClientRects().length > 0;
  }

  function containsSubmitControl(element) {
    return !!element && !!element.querySelector(SUBMIT_SELECTOR);
  }

  function isAutoTargetPage() {
    var path = window.location.pathname || "";

    return path.indexOf("/admin/") === 0 &&
      (path.indexOf("/new") !== -1 || path.indexOf("/edit") !== -1);
  }

  function isIgnoredAction(action) {
    return action.classList.contains("form-actions--top") ||
      action.getAttribute("data-fixed-submit-exclude") === "true";
  }

  function explicitInstance() {
    var action = toArray(document.querySelectorAll(".main-content " + EXPLICIT_ACTION_SELECTOR)).find(function(candidate) {
      return containsSubmitControl(candidate) && !isIgnoredAction(candidate);
    });
    var form = closest(action, "form");

    if (!action || !form || !containsSubmitControl(action) || isIgnoredAction(action)) {
      return null;
    }

    return {
      form: form,
      action: action
    };
  }

  function actionCandidates(form) {
    return toArray(form.querySelectorAll(ACTION_SELECTOR)).filter(function(action) {
      return closest(action, "form") === form &&
        containsSubmitControl(action) &&
        !isIgnoredAction(action);
    });
  }

  function autoInstances() {
    return toArray(document.querySelectorAll(".main-content form")).map(function(form) {
      var candidates = actionCandidates(form);
      var action = candidates[candidates.length - 1];

      if (!action) return null;

      return {
        form: form,
        action: action
      };
    }).filter(Boolean);
  }

  function anchorPosition() {
    var header = document.querySelector(".main-content__header");
    var headerBottom = header && isVisible(header) ? header.getBoundingClientRect().bottom : 0;
    var viewportAnchor = Math.min(window.innerHeight * 0.35, 320);

    return Math.min(
      Math.max(headerBottom + 24, viewportAnchor),
      Math.max(window.innerHeight - 48, 0)
    );
  }

  function visibleInstances(instances) {
    return instances.map(function(instance) {
      instance.formRect = instance.form.getBoundingClientRect();
      instance.actionRect = instance.action.getBoundingClientRect();
      return instance;
    }).filter(function(instance) {
      return isVisible(instance.form) &&
        isVisible(instance.action) &&
        instance.formRect.bottom > 0 &&
        instance.formRect.top < window.innerHeight;
    });
  }

  function selectAutoInstance(instances) {
    if (!instances.length) return null;

    var anchorY = anchorPosition();
    var containing = instances.filter(function(instance) {
      return instance.formRect.top <= anchorY && instance.formRect.bottom > anchorY;
    });

    if (containing.length) {
      return containing.sort(function(left, right) {
        return right.formRect.top - left.formRect.top;
      })[0];
    }

    var below = instances.filter(function(instance) {
      return instance.formRect.top > anchorY;
    });

    if (below.length) {
      return below.sort(function(left, right) {
        return left.formRect.top - right.formRect.top;
      })[0];
    }

    return instances.sort(function(left, right) {
      return right.formRect.bottom - left.formRect.bottom;
    })[0];
  }

  function currentInstance() {
    var explicit = explicitInstance();
    if (explicit) return explicit;

    if (!isAutoTargetPage()) return null;

    return selectAutoInstance(visibleInstances(autoInstances()));
  }

  function ensureBar() {
    if (bar) return;

    bar = document.createElement("div");
    bar.className = "admin-fixed-submit-bar";
    bar.hidden = true;

    barActions = document.createElement("div");
    barActions.className = "admin-fixed-submit-bar__actions";
    bar.appendChild(barActions);

    document.body.appendChild(bar);
  }

  function hideBar() {
    ensureBar();
    bar.hidden = true;
    bar.style.removeProperty("--fixed-submit-left");
    bar.style.removeProperty("--fixed-submit-width");
    barActions.innerHTML = "";
  }

  function stripIds(node) {
    if (!node || node.nodeType !== 1) return;

    node.removeAttribute("id");
    toArray(node.querySelectorAll("[id]")).forEach(function(child) {
      child.removeAttribute("id");
    });
  }

  function syncCloneControls(clone, sourceAction) {
    var sourceControls = toArray(sourceAction.querySelectorAll(SUBMIT_SELECTOR));
    var cloneControls = toArray(clone.querySelectorAll(SUBMIT_SELECTOR));

    cloneControls.forEach(function(cloneControl, index) {
      var sourceControl = sourceControls[index];

      if (!sourceControl) {
        cloneControl.remove();
        return;
      }

      if (cloneControl.tagName === "INPUT") {
        cloneControl.type = "button";
      } else if (cloneControl.tagName === "BUTTON") {
        cloneControl.type = "button";
      }

      cloneControl.disabled = !!sourceControl.disabled;

      cloneControl.addEventListener("click", function(event) {
        event.preventDefault();
        if (sourceControl.disabled) return;
        sourceControl.click();
      });
    });
  }

  function renderClone(instance) {
    ensureBar();
    barActions.innerHTML = "";

    var clone = instance.action.cloneNode(true);
    stripIds(clone);
    clone.removeAttribute("data-fixed-submit-actions");
    clone.classList.add("admin-fixed-submit-bar__action-clone");
    syncCloneControls(clone, instance.action);

    barActions.appendChild(clone);
  }

  function fixedFrame(instance) {
    var mainContent = closest(instance.form, ".main-content") || document.querySelector(".main-content");
    var section = closest(instance.action, ".main-content__body") || closest(instance.form, ".main-content__body") || instance.form;
    var viewportMargin = window.innerWidth <= 767 ? 8 : 16;
    var mainRect = mainContent ? mainContent.getBoundingClientRect() : { left: 0, right: window.innerWidth };
    var sectionRect = section.getBoundingClientRect();
    var left = Math.max(mainRect.left, sectionRect.left, viewportMargin);
    var right = Math.min(mainRect.right, sectionRect.right, window.innerWidth - viewportMargin);

    return {
      left: Math.max(left, viewportMargin),
      width: Math.max(right - left, 0)
    };
  }

  function shouldPin(instance) {
    var actionRect = instance.action.getBoundingClientRect();
    var revealThreshold = Math.min(96, Math.max(48, actionRect.height));

    return isVisible(instance.form) &&
      isVisible(instance.action) &&
      instance.form.getBoundingClientRect().bottom > 0 &&
      instance.form.getBoundingClientRect().top < window.innerHeight &&
      actionRect.top > window.innerHeight - revealThreshold;
  }

  function observeAction(action) {
    if (observedAction === action) return;

    if (observer) observer.disconnect();

    observedAction = action;
    if (!action) return;

    observer = new MutationObserver(function() {
      scheduleSync();
    });

    observer.observe(action, {
      subtree: true,
      childList: true,
      attributes: true,
      characterData: true
    });
  }

  function sync() {
    var instance = currentInstance();

    if (!instance) {
      observeAction(null);
      hideBar();
      return;
    }

    observeAction(instance.action);

    if (!shouldPin(instance)) {
      hideBar();
      return;
    }

    var frame = fixedFrame(instance);
    if (frame.width <= 0) {
      hideBar();
      return;
    }

    renderClone(instance);
    bar.style.setProperty("--fixed-submit-left", frame.left + "px");
    bar.style.setProperty("--fixed-submit-width", frame.width + "px");
    bar.hidden = false;
  }

  function scheduleSync() {
    if (scheduled) return;

    scheduled = true;
    (window.requestAnimationFrame || window.setTimeout)(function() {
      scheduled = false;
      sync();
    }, 16);
  }

  function initialize() {
    ensureBar();
    scheduleSync();
  }

  document.addEventListener("DOMContentLoaded", initialize);
  window.addEventListener("load", scheduleSync);
  window.addEventListener("scroll", scheduleSync, { passive: true });
  window.addEventListener("resize", scheduleSync);
})();
