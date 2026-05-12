(function () {
  function getRoleNode(container, role) {
    return container.querySelector('[data-admin-datetime-role="' + role + '"]');
  }

  function getTargetNode(container, target) {
    return container.querySelector('[data-admin-datetime-target="' + target + '"]');
  }

  function getVisibleInputs(container) {
    return ['date-input', 'time-input']
      .map(function (role) {
        return getRoleNode(container, role);
      })
      .filter(Boolean);
  }

  function getDateInput(container) {
    return getRoleNode(container, 'date-input');
  }

  function getTimeInput(container) {
    return getRoleNode(container, 'time-input');
  }

  function readValue(container, role) {
    var input = getRoleNode(container, role);
    return input ? String(input.value || '').trim() : '';
  }

  function readDateValue(container) {
    return readValue(container, 'date-input');
  }

  function readTimeValue(container) {
    return readValue(container, 'time-input');
  }

  function normalizeFullWidthDigitsAndColon(value) {
    return String(value || '')
      .replace(/[０-９]/g, function (char) {
        return String.fromCharCode(char.charCodeAt(0) - 65248);
      })
      .replace(/：/g, ':');
  }

  function sanitizeTimeValue(value, options) {
    var config = options || {};
    var normalizeFullWidth = !!config.normalizeFullWidth;
    var autoInsertColon = config.autoInsertColon !== false;
    var text = String(value || '').replace(/\s+/g, '');

    if (normalizeFullWidth) {
      text = normalizeFullWidthDigitsAndColon(text);
      text = text.replace(/[^0-9:]/g, '');
    } else {
      text = text.replace(/[^0-9０-９:：]/g, '');
    }

    if (!text.length) {
      return '';
    }

    if (!normalizeFullWidth && /^\d{4}$/.test(text) && autoInsertColon) {
      return text.slice(0, 2) + ':' + text.slice(2, 4);
    }

    if (normalizeFullWidth && /^\d{4}$/.test(text) && autoInsertColon) {
      return text.slice(0, 2) + ':' + text.slice(2, 4);
    }

    var separatorPattern = normalizeFullWidth ? ':' : '[:：]';
    var match = text.match(new RegExp('^([0-9０-９]{0,2})(' + separatorPattern + '?)([0-9０-９]{0,2}).*$'));
    if (match && match[2]) {
      var separator = normalizeFullWidth ? ':' : match[2];
      return (match[1] || '') + separator + (match[3] || '');
    }

    return text.slice(0, 4);
  }

  function sanitizeTimeInput(input, options) {
    if (!input) {
      return;
    }

    var sanitized = sanitizeTimeValue(input.value, options);
    if (input.value !== sanitized) {
      input.value = sanitized;
    }
  }

  function parseDateValue(value) {
    var text = String(value || '').trim();
    if (!text.length) {
      return { blank: true, valid: false };
    }

    var match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) {
      return { blank: false, valid: false };
    }

    var year = Number(match[1]);
    var month = Number(match[2]);
    var day = Number(match[3]);
    var date = new Date(year, month - 1, day);

    if (
      date.getFullYear() !== year ||
      date.getMonth() !== month - 1 ||
      date.getDate() !== day
    ) {
      return { blank: false, valid: false };
    }

    return { blank: false, valid: true, normalized: text };
  }

  function parseTimeValue(value) {
    var text = sanitizeTimeValue(value, {
      normalizeFullWidth: true,
      autoInsertColon: false,
    });

    if (!text.length) {
      return { blank: true, valid: false };
    }

    if (/^\d{1,2}:$/.test(text) || /^\d{1,2}$/.test(text)) {
      return { blank: false, valid: false, incomplete: true };
    }

    var hour;
    var minute;

    if (/^\d{1,2}:\d{1,2}$/.test(text)) {
      var colonParts = text.split(':', 2);
      hour = Number(colonParts[0]);
      minute = Number(colonParts[1]);
    } else if (/^\d{3,4}$/.test(text)) {
      var digits = text.padStart(4, '0');
      hour = Number(digits.slice(0, 2));
      minute = Number(digits.slice(2, 4));
    } else {
      return { blank: false, valid: false };
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return { blank: false, valid: false };
    }

    var normalized = String(hour).padStart(2, '0') + ':' + String(minute).padStart(2, '0');
    return {
      blank: false,
      valid: true,
      normalized: normalized,
      segments: {
        hour: normalized.slice(0, 2),
        minute: normalized.slice(3, 5),
      },
    };
  }

  function compareDateStrings(left, right) {
    if (!left || !right) {
      return 0;
    }

    if (left === right) {
      return 0;
    }

    return left < right ? -1 : 1;
  }

  function invalidate(message, inputs) {
    return {
      valid: false,
      message: message,
      invalidInputs: inputs.filter(Boolean),
    };
  }

  function validateContainer(container) {
    var mode = container.dataset.adminDatetimeMode;
    var required = container.dataset.adminDatetimeRequired === 'true';
    var minDate = String(container.dataset.adminDatetimeMinDate || '').trim();
    var maxDate = String(container.dataset.adminDatetimeMaxDate || '').trim();
    var includeDate = mode !== 'time_only';
    var currentDateInput = getDateInput(container);
    var currentTimeInput = getTimeInput(container);
    var rawDateValue = includeDate ? readDateValue(container) : '';
    var rawTimeValue = readTimeValue(container);
    var datePresent = includeDate && rawDateValue.length > 0;
    var timePresent = rawTimeValue.length > 0;

    if (includeDate) {
      if (required && !datePresent && !timePresent) {
        return invalidate('日時を入力してください。', [currentDateInput, currentTimeInput]);
      }

      if (!datePresent && !timePresent) {
        return {
          valid: true,
          blank: true,
          normalizedDate: '',
          normalizedTime: '',
          normalizedTimeSegments: { hour: '', minute: '' },
        };
      }

      if (!datePresent) {
        return invalidate('日付を入力してください。', [currentDateInput]);
      }

      var normalizedDate = parseDateValue(rawDateValue);
      if (!normalizedDate.valid) {
        return invalidate('日付を正しく入力してください。', [currentDateInput]);
      }

      if (minDate && compareDateStrings(normalizedDate.normalized, minDate) < 0) {
        return invalidate('日付は' + minDate.replace(/-/g, '/') + '以降で入力してください。', [currentDateInput]);
      }

      if (maxDate && compareDateStrings(normalizedDate.normalized, maxDate) > 0) {
        return invalidate('日付は' + maxDate.replace(/-/g, '/') + '以前で入力してください。', [currentDateInput]);
      }

      if (!timePresent) {
        return invalidate('時刻を入力してください。', [currentTimeInput]);
      }

      var normalizedTime = parseTimeValue(rawTimeValue);
      if (!normalizedTime.valid) {
        return invalidate('時刻を正しく入力してください。', [currentTimeInput]);
      }

      return {
        valid: true,
        blank: false,
        normalizedDate: normalizedDate.normalized,
        normalizedTime: normalizedTime.normalized,
        normalizedTimeSegments: normalizedTime.segments,
      };
    }

    if (required && !timePresent) {
      return invalidate('時刻を入力してください。', [currentTimeInput]);
    }

    if (!timePresent) {
      return {
        valid: true,
        blank: true,
        normalizedDate: '',
        normalizedTime: '',
        normalizedTimeSegments: { hour: '', minute: '' },
      };
    }

    var normalizedTimeOnly = parseTimeValue(rawTimeValue);
    if (!normalizedTimeOnly.valid) {
      return invalidate('時刻を正しく入力してください。', [currentTimeInput]);
    }

    return {
      valid: true,
      blank: false,
      normalizedDate: '',
      normalizedTime: normalizedTimeOnly.normalized,
      normalizedTimeSegments: normalizedTimeOnly.segments,
    };
  }

  function writeVisibleDate(container, value) {
    var input = getDateInput(container);
    if (input) {
      input.value = value || '';
    }
  }

  function writeVisibleTime(container, value) {
    var input = getTimeInput(container);
    if (input) {
      input.value = value || '';
    }
  }

  function clearTargets(container) {
    var mode = container.dataset.adminDatetimeMode;

    if (mode === 'combined') {
      var combinedTarget = getTargetNode(container, 'combined');
      if (combinedTarget) combinedTarget.value = '';
      return;
    }

    if (mode === 'split_datetime') {
      var dateTarget = getTargetNode(container, 'date');
      var hourTarget = getTargetNode(container, 'hour');
      var minuteTarget = getTargetNode(container, 'minute');

      if (dateTarget) dateTarget.value = '';
      if (hourTarget) hourTarget.value = '';
      if (minuteTarget) minuteTarget.value = '';
      return;
    }

    if (mode === 'date_and_time') {
      var splitDateTarget = getTargetNode(container, 'date');
      var timeTarget = getTargetNode(container, 'time');

      if (splitDateTarget) splitDateTarget.value = '';
      if (timeTarget) timeTarget.value = '';
      return;
    }

    if (mode === 'time_only') {
      var singleTimeTarget = getTargetNode(container, 'time');
      if (singleTimeTarget) singleTimeTarget.value = '';
    }
  }

  function writeTargets(container, state) {
    var mode = container.dataset.adminDatetimeMode;

    if (!state.valid || state.blank) {
      clearTargets(container);
      return;
    }

    if (mode === 'combined') {
      var combinedTarget = getTargetNode(container, 'combined');
      if (combinedTarget) combinedTarget.value = state.normalizedDate + 'T' + state.normalizedTime;
      return;
    }

    if (mode === 'split_datetime') {
      var dateTarget = getTargetNode(container, 'date');
      var hourTarget = getTargetNode(container, 'hour');
      var minuteTarget = getTargetNode(container, 'minute');

      if (dateTarget) dateTarget.value = state.normalizedDate;
      if (hourTarget) hourTarget.value = state.normalizedTimeSegments.hour;
      if (minuteTarget) minuteTarget.value = state.normalizedTimeSegments.minute;
      return;
    }

    if (mode === 'date_and_time') {
      var splitDateTarget = getTargetNode(container, 'date');
      var timeTarget = getTargetNode(container, 'time');

      if (splitDateTarget) splitDateTarget.value = state.normalizedDate;
      if (timeTarget) timeTarget.value = state.normalizedTime;
      return;
    }

    if (mode === 'time_only') {
      var singleTimeTarget = getTargetNode(container, 'time');
      if (singleTimeTarget) singleTimeTarget.value = state.normalizedTime;
    }
  }

  function applyValidationState(container, state) {
    var errorNode = getRoleNode(container, 'error');
    var inputs = getVisibleInputs(container);
    var invalidInputs = state.valid ? [] : state.invalidInputs || inputs;

    container.dataset.adminDatetimeValid = state.valid ? 'true' : 'false';
    container.classList.toggle('admin-datetime-input--invalid', !state.valid);

    if (errorNode) {
      errorNode.textContent = state.message || '';
    }

    inputs.forEach(function (input) {
      input.setCustomValidity('');
      input.setAttribute('aria-invalid', 'false');
    });

    invalidInputs.forEach(function (input) {
      input.setCustomValidity(state.message || '');
      input.setAttribute('aria-invalid', 'true');
    });
  }

  function validateAndSyncContainer(container, options) {
    var config = options || {};
    var timeInput = getTimeInput(container);

    if (config.sanitizeVisible !== false) {
      sanitizeTimeInput(timeInput, {
        normalizeFullWidth: !!config.normalizeFullWidth,
        autoInsertColon: config.autoInsertColon !== false,
      });
    }

    var state = validateContainer(container);

    if (config.normalizeVisible && state.valid) {
      if (state.normalizedDate) {
        writeVisibleDate(container, state.normalizedDate);
      }
      if (state.normalizedTime) {
        writeVisibleTime(container, state.normalizedTime);
      }
    }

    writeTargets(container, state);
    applyValidationState(container, state);

    return state;
  }

  function parseCombinedTarget(value) {
    var text = String(value || '').trim();
    if (!text.length) {
      return { rawDate: '', rawTime: '' };
    }

    var match = text.match(/^(\d{4}[/-]\d{1,2}[/-]\d{1,2})(?:[T\s]+(.+))?$/);
    if (match) {
      return {
        rawDate: match[1] || '',
        rawTime: match[2] || '',
      };
    }

    return { rawDate: '', rawTime: text };
  }

  function syncVisibleFromTargets(container) {
    var mode = container.dataset.adminDatetimeMode;
    var rawDate = '';
    var rawTime = '';

    if (mode === 'combined') {
      var combinedTarget = getTargetNode(container, 'combined');
      var combinedValues = parseCombinedTarget(combinedTarget ? combinedTarget.value : '');
      rawDate = combinedValues.rawDate;
      rawTime = combinedValues.rawTime;
    } else if (mode === 'split_datetime') {
      var splitDateTarget = getTargetNode(container, 'date');
      var splitHourTarget = getTargetNode(container, 'hour');
      var splitMinuteTarget = getTargetNode(container, 'minute');
      rawDate = splitDateTarget ? splitDateTarget.value : '';
      if (splitHourTarget && splitMinuteTarget && (splitHourTarget.value || splitMinuteTarget.value)) {
        rawTime = String(splitHourTarget.value || '') + ':' + String(splitMinuteTarget.value || '');
      }
    } else if (mode === 'date_and_time') {
      var dateTarget = getTargetNode(container, 'date');
      var timeTarget = getTargetNode(container, 'time');
      rawDate = dateTarget ? dateTarget.value : '';
      rawTime = timeTarget ? timeTarget.value : '';
    } else if (mode === 'time_only') {
      var singleTimeTarget = getTargetNode(container, 'time');
      rawTime = singleTimeTarget ? singleTimeTarget.value : '';
    }

    if (mode !== 'time_only') {
      writeVisibleDate(container, rawDate);
    }

    if (rawTime) {
      var parsedTime = parseTimeValue(rawTime);
      writeVisibleTime(container, parsedTime.valid ? parsedTime.normalized : sanitizeTimeValue(rawTime, { normalizeFullWidth: true, autoInsertColon: false }));
    } else {
      writeVisibleTime(container, '');
    }

    return validateAndSyncContainer(container, { normalizeVisible: true, sanitizeVisible: false });
  }

  function collectContainers(root) {
    if (!root) {
      return [];
    }

    if (root.matches && root.matches('[data-admin-datetime-input="true"]')) {
      return [root];
    }

    if (!root.querySelectorAll) {
      return [];
    }

    return Array.prototype.slice.call(root.querySelectorAll('[data-admin-datetime-input="true"]'));
  }

  function validateWithin(root, options) {
    var containers = collectContainers(root);
    var firstInvalidInput = null;
    var valid = true;

    containers.forEach(function (container) {
      var state = validateAndSyncContainer(container, options);
      if (!state.valid) {
        valid = false;
        if (!firstInvalidInput) {
          firstInvalidInput = (state.invalidInputs && state.invalidInputs[0]) || getVisibleInputs(container)[0] || null;
        }
      }
    });

    return {
      valid: valid,
      firstInvalidInput: firstInvalidInput,
    };
  }

  function reportValidityWithin(root) {
    var result = validateWithin(root, { normalizeVisible: true, normalizeFullWidth: true });
    if (!result.valid && result.firstInvalidInput) {
      result.firstInvalidInput.focus();
      if (typeof result.firstInvalidInput.reportValidity === 'function') {
        result.firstInvalidInput.reportValidity();
      }
    }
    return result.valid;
  }

  function bindForm(container) {
    var form = container.closest ? container.closest('form') : null;
    if (!form || form.__adminDatetimeSubmitBound) {
      return;
    }

    form.addEventListener('submit', function (event) {
      if (!reportValidityWithin(form)) {
        event.preventDefault();
        event.stopPropagation();
      }
    });

    form.__adminDatetimeSubmitBound = true;
  }

  function bindReplaceOnFocus(input) {
    if (!input) {
      return;
    }

    input.addEventListener('focus', function () {
      if (!input.value) {
        return;
      }

      input.select();
      input.dataset.adminDatetimeSelectAll = 'true';
    });

    input.addEventListener('mouseup', function (event) {
      if (input.dataset.adminDatetimeSelectAll === 'true') {
        event.preventDefault();
        delete input.dataset.adminDatetimeSelectAll;
      }
    });

    input.addEventListener('blur', function () {
      delete input.dataset.adminDatetimeSelectAll;
    });
  }

  function bindContainer(container) {
    if (!container || container.dataset.adminDatetimeBound === 'true') {
      return;
    }

    container.dataset.adminDatetimeBound = 'true';

    var dateInput = getDateInput(container);
    var timeInput = getTimeInput(container);

    validateAndSyncContainer(container, { normalizeVisible: true });

    if (dateInput) {
      dateInput.addEventListener('input', function () {
        validateAndSyncContainer(container, { sanitizeVisible: false });
      });

      dateInput.addEventListener('change', function () {
        validateAndSyncContainer(container, { normalizeVisible: true, sanitizeVisible: false });
      });
    }

    if (timeInput) {
      bindReplaceOnFocus(timeInput);

      timeInput.addEventListener('input', function () {
        sanitizeTimeInput(timeInput, { autoInsertColon: true });
        validateAndSyncContainer(container, { sanitizeVisible: false });
      });

      timeInput.addEventListener('blur', function () {
        sanitizeTimeInput(timeInput, { normalizeFullWidth: true, autoInsertColon: true });
        validateAndSyncContainer(container, {
          normalizeVisible: true,
          sanitizeVisible: false,
        });
      });

      timeInput.addEventListener('change', function () {
        sanitizeTimeInput(timeInput, { normalizeFullWidth: true, autoInsertColon: true });
        validateAndSyncContainer(container, {
          normalizeVisible: true,
          sanitizeVisible: false,
        });
      });
    }

    bindForm(container);
  }

  function initWithin(root) {
    var base = root && root.querySelectorAll ? root : document;
    collectContainers(base).forEach(bindContainer);
  }

  window.AdminDateTimeInput = {
    initWithin: initWithin,
    syncFromTargets: function (root) {
      collectContainers(root).forEach(syncVisibleFromTargets);
    },
    validateWithin: validateWithin,
    reportValidityWithin: reportValidityWithin,
  };

  if (document.readyState === 'loading') {
    document.addEventListener(
      'DOMContentLoaded',
      function () {
        initWithin(document);
      },
      { once: true }
    );
  } else {
    initWithin(document);
  }

  window.addEventListener('pageshow', function () {
    initWithin(document);
  });
})();
