(function() {
  var FORM_SELECTOR = "[data-yg-administrate-filter-form]";

  function initializeForms(root) {
    var forms = [];

    if (root.matches && root.matches(FORM_SELECTOR)) {
      forms.push(root);
    }

    if (root.querySelectorAll) {
      root.querySelectorAll(FORM_SELECTOR).forEach(function(formEl) {
        forms.push(formEl);
      });
    }

    forms.forEach(initializeForm);
  }

  function initializeForm(formEl) {
    if (formEl.dataset.ygAdministrateFilterFormInitialized === "true") {
      syncDatetimeFilterFields(formEl);
      return;
    }

    formEl.dataset.ygAdministrateFilterFormInitialized = "true";
    formEl.addEventListener("submit", function() {
      syncDatetimeFilterFields(formEl);
    });

    formEl.querySelectorAll("[data-datetime-filter]").forEach(function(groupEl) {
      groupEl.addEventListener("change", function(event) {
        handleDatetimeFilterChange(formEl, groupEl, event);
      });

      syncBlankMinuteOptionState(groupEl);
      syncDatetimeTimeDisabledState(groupEl);
    });

    formEl.querySelectorAll('[data-behavior="filter-form-clear"]').forEach(function(buttonEl) {
      buttonEl.addEventListener("click", function() {
        clearFormFields(formEl);
      });
    });

    formEl.querySelectorAll('[data-behavior="checkbox-group-select-all"]').forEach(function(buttonEl) {
      buttonEl.addEventListener("click", function() {
        setCheckboxGroupState(formEl, buttonEl.dataset.target, true);
      });
    });

    formEl.querySelectorAll('[data-behavior="checkbox-group-clear-all"]').forEach(function(buttonEl) {
      buttonEl.addEventListener("click", function() {
        setCheckboxGroupState(formEl, buttonEl.dataset.target, false);
      });
    });

    syncDatetimeFilterFields(formEl);
  }

  function clearFormFields(formEl) {
    formEl.querySelectorAll("input, select, textarea").forEach(function(fieldEl) {
      if (fieldEl.disabled || fieldEl.type === "hidden" || fieldEl.type === "submit") {
        return;
      }

      if (fieldEl.tagName === "SELECT") {
        fieldEl.value = "";
        return;
      }

      if (fieldEl.type === "checkbox" || fieldEl.type === "radio") {
        fieldEl.checked = false;
        return;
      }

      fieldEl.value = "";
    });

    formEl.querySelectorAll("[data-datetime-filter]").forEach(function(groupEl) {
      clearDatetimeTimeParts(groupEl);
      syncDatetimeTimeDisabledState(groupEl);
      syncBlankMinuteOptionState(groupEl);
    });

    syncDatetimeFilterFields(formEl);
  }

  function setCheckboxGroupState(formEl, groupName, checked) {
    if (!groupName) return;

    formEl.querySelectorAll('[data-checkbox-group-item="' + groupName + '"]').forEach(function(checkboxEl) {
      if (!checkboxEl.disabled) {
        checkboxEl.checked = checked;
      }
    });
  }

  function handleDatetimeFilterChange(formEl, groupEl, event) {
    if (event.target && event.target.dataset.datetimePart === "date") {
      if (event.target.value) {
        syncRangeEndDate(formEl, groupEl);
      } else {
        clearDatetimeTimeParts(groupEl);
      }
    }

    if (event.target && event.target.dataset.datetimePart === "hour") {
      syncDatetimeMinuteOnHourChange(groupEl);
    }

    if (event.target && event.target.dataset.datetimePart === "minute") {
      preventBlankDatetimeMinute(groupEl);
    }

    syncDatetimeTimeDisabledState(groupEl);
    syncBlankMinuteOptionState(groupEl);
    syncDatetimeFilterFields(formEl);
  }

  function syncRangeEndDate(formEl, groupEl) {
    var endTarget = groupEl.dataset.datetimeEndTarget;
    if (!endTarget) return;

    var startDateEl = groupEl.querySelector('[data-datetime-part="date"]');
    if (!startDateEl || !startDateEl.value) return;

    var endGroupEl = formEl.querySelector('[data-datetime-field="' + endTarget + '"]');
    if (!endGroupEl) return;

    var endDateEl = endGroupEl.querySelector('[data-datetime-part="date"]');
    if (!endDateEl || endDateEl.value) return;

    endDateEl.value = startDateEl.value;
  }

  function clearDatetimeTimeParts(groupEl) {
    var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
    var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');

    if (hourEl) hourEl.value = "";
    if (minuteEl) minuteEl.value = "";
  }

  function syncDatetimeMinuteOnHourChange(groupEl) {
    var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
    var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');
    if (!hourEl || !minuteEl) return;

    minuteEl.value = hourEl.value ? "00" : "";
  }

  function preventBlankDatetimeMinute(groupEl) {
    var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
    var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');
    if (!hourEl || !minuteEl) return;

    if (hourEl.value && minuteEl.value === "") {
      minuteEl.value = "00";
    }
  }

  function syncBlankMinuteOptionState(groupEl) {
    var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
    var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');
    if (!hourEl || !minuteEl) return;

    var blankOptionEl = minuteEl.querySelector('option[value=""]');
    if (blankOptionEl) {
      blankOptionEl.disabled = !!hourEl.value;
    }
  }

  function syncDatetimeTimeDisabledState(groupEl) {
    var dateEl = groupEl.querySelector('[data-datetime-part="date"]');
    var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
    var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');
    var dateDisabled = !dateEl || !dateEl.value;
    var minuteDisabled = dateDisabled || !hourEl || !hourEl.value;

    if (hourEl) hourEl.disabled = dateDisabled;
    if (minuteEl) minuteEl.disabled = minuteDisabled;
  }

  function syncDatetimeFilterFields(formEl) {
    formEl.querySelectorAll("[data-datetime-filter]").forEach(function(groupEl) {
      var combinedEl = groupEl.querySelector('[data-datetime-part="combined"]');
      var dateEl = groupEl.querySelector('[data-datetime-part="date"]');
      var hourEl = groupEl.querySelector('[data-datetime-part="hour"]');
      var minuteEl = groupEl.querySelector('[data-datetime-part="minute"]');

      if (!combinedEl || !dateEl || !hourEl || !minuteEl) return;

      syncDatetimeTimeDisabledState(groupEl);

      if (!dateEl.value) {
        combinedEl.value = "";
        combinedEl.setAttribute("value", "");
        return;
      }

      combinedEl.value = hourEl.value && minuteEl.value ? dateEl.value + "T" + hourEl.value + ":" + minuteEl.value : dateEl.value;
      combinedEl.setAttribute("value", combinedEl.value);
    });
  }

  function initializeFromDocument() {
    initializeForms(document);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeFromDocument, { once: true });
  } else {
    initializeFromDocument();
  }

  document.addEventListener("turbo:load", initializeFromDocument);
})();

