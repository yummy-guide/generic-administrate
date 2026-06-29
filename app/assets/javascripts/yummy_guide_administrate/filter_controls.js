(function() {
  function initialize(root) {
    var scope = root || document;

    scope.querySelectorAll('[data-admin-filter-form="true"]').forEach(initializeForm);
    scope.querySelectorAll('[data-admin-filter-controls="true"]').forEach(initializeControls);
  }

  function initializeForm(formEl) {
    if (formEl.dataset.adminFilterControlsInitialized === "true") return;

    formEl.dataset.adminFilterControlsInitialized = "true";

    formEl.addEventListener("submit", function(event) {
      if (formEl.dataset.submitMode !== "event") return;

      event.preventDefault();
      document.dispatchEvent(new CustomEvent("yummy-guide:administrate-filter:submit", {
        detail: {
          form: formEl,
          formData: new FormData(formEl)
        }
      }));
    });
  }

  function initializeControls(rootEl) {
    if (!rootEl || rootEl.dataset.adminFilterModalInitialized === "true") return;

    var modalRootEl = modalRootFor(rootEl);
    var formScopeEl = modalRootEl || rootEl;
    var triggerEl = rootEl.querySelector("a, button");
    var formEl = formScopeEl.querySelector("form");
    var overlayEl = overlayFor(rootEl, modalRootEl);

    if (!triggerEl || !formEl || !overlayEl) return;

    rootEl.dataset.adminFilterModalInitialized = "true";

    triggerEl.addEventListener("click", showForm);
    overlayEl.addEventListener("click", hideForm);
    formEl.querySelectorAll('[data-behavior="filter-form-close"]').forEach(function(buttonEl) {
      buttonEl.addEventListener("click", hideForm);
    });
    document.addEventListener("keydown", function(event) {
      if (event.key === "Escape") hideForm();
    });

    function showForm(event) {
      if (event) event.preventDefault();

      document.documentElement.classList.add("admin-filter-open");
      document.body.classList.add("admin-filter-open");
      overlayEl.style.display = "block";
      formEl.style.display = "flex";
    }

    function hideForm() {
      document.documentElement.classList.remove("admin-filter-open");
      document.body.classList.remove("admin-filter-open");
      overlayEl.style.removeProperty("display");
      formEl.style.removeProperty("display");
    }
  }

  function modalRootFor(rootEl) {
    var modalId = rootEl.dataset.adminFilterModalId;
    if (!modalId) return null;

    return document.getElementById(modalId);
  }

  function overlayFor(rootEl, modalRootEl) {
    if (modalRootEl) {
      return modalRootEl.querySelector("[data-admin-filter-overlay]");
    }

    if (rootEl.previousElementSibling && rootEl.previousElementSibling.matches("[data-admin-filter-overlay]")) {
      return rootEl.previousElementSibling;
    }

    return rootEl.querySelector("[data-admin-filter-overlay]");
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() { initialize(document); }, { once: true });
  } else {
    initialize(document);
  }

  document.addEventListener("turbo:load", function() { initialize(document); });
})();
