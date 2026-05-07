(function() {
  function dispatchCopyEvent(name, detail) {
    document.dispatchEvent(new CustomEvent(name, { detail: detail }));
  }

  function showCopiedFeedback(trigger) {
    var container = trigger.closest(".admin-copy-cell");
    if (!container) return;

    var feedback = container.querySelector("[data-role='copy-feedback']");
    if (!feedback) return;

    feedback.textContent = "Copied";
    container.classList.add("is-copied");

    if (container.copyFeedbackTimer) {
      clearTimeout(container.copyFeedbackTimer);
    }

    container.copyFeedbackTimer = setTimeout(function() {
      container.classList.remove("is-copied");
      feedback.textContent = "";
      container.copyFeedbackTimer = null;
    }, 1600);
  }

  function copyText(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise(function(resolve, reject) {
      try {
        var input = document.createElement("textarea");
        input.value = text;
        input.setAttribute("readonly", "");
        input.style.position = "absolute";
        input.style.left = "-9999px";
        document.body.appendChild(input);
        input.select();
        document.execCommand("copy");
        document.body.removeChild(input);
        resolve();
      } catch (error) {
        reject(error);
      }
    });
  }

  function copyCell(trigger) {
    var text = trigger.getAttribute("data-copy-text");
    if (!text) return;

    copyText(text).then(function() {
      showCopiedFeedback(trigger);
      dispatchCopyEvent("yummy-guide-administrate:copied", {
        text: text,
        trigger: trigger
      });
    }).catch(function(error) {
      dispatchCopyEvent("yummy-guide-administrate:copy-error", {
        text: text,
        trigger: trigger,
        error: error
      });
    });
  }

  document.addEventListener("click", function(event) {
    var trigger = event.target.closest("[data-behavior='copy-cell']");
    if (!trigger) return;

    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === "function") {
      event.stopImmediatePropagation();
    }

    copyCell(trigger);
  }, true);
})();
