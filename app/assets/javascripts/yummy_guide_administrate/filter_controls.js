(function() {
  function initialize(root) {
    var scope = root || document;
    scope.querySelectorAll('[data-admin-filter-form="true"]').forEach(function(formEl) {
      if (formEl.dataset.adminFilterControlsInitialized === 'true') return;

      formEl.dataset.adminFilterControlsInitialized = 'true';

      formEl.addEventListener('submit', function(event) {
        if (formEl.dataset.submitMode !== 'event') return;

        event.preventDefault();
        document.dispatchEvent(new CustomEvent('yummy-guide:administrate-filter:submit', {
          detail: {
            form: formEl,
            formData: new FormData(formEl)
          }
        }));
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() { initialize(document); }, { once: true });
  } else {
    initialize(document);
  }

  document.addEventListener('turbo:load', function() { initialize(document); });
})();
