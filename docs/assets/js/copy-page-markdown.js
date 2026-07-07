(function () {
  function writeToClipboard(text) {
    if (
      window.isSecureContext &&
      window.navigator &&
      window.navigator.clipboard &&
      window.navigator.clipboard.writeText
    ) {
      return window.navigator.clipboard.writeText(text);
    }

    return new Promise(function (resolve, reject) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'fixed';
      textarea.style.top = '-9999px';
      document.body.appendChild(textarea);
      textarea.select();

      try {
        if (document.execCommand('copy')) {
          resolve();
        } else {
          reject(new Error('Copy command failed.'));
        }
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function copyPageMarkdown(button) {
    if (!button) {
      return;
    }

    var container = button.closest('.page-actions') || document;
    var textarea = container.querySelector('.vp-raw-markdown');
    if (!textarea) {
      return;
    }

    var icon = button.querySelector('.copy-md-icon');
    var label = button.querySelector('.copy-md-label');

    function setCopied(copied) {
      button.classList.toggle('copied', copied);
      if (icon) {
        icon.classList.toggle('vpi-copy', !copied);
        icon.classList.toggle('vpi-check', copied);
      }
      if (label) {
        label.textContent = copied ? 'Copied' : 'Copy page';
      }
    }

    writeToClipboard(textarea.value)
      .then(function () {
        setCopied(true);
        if (button._copyTimeout) {
          window.clearTimeout(button._copyTimeout);
        }
        button._copyTimeout = window.setTimeout(function () {
          setCopied(false);
        }, 2000);
      })
      .catch(function () {
        if (label) {
          label.textContent = 'Copy failed';
          window.setTimeout(function () {
            label.textContent = 'Copy page';
          }, 2500);
        }
      });
  }

  function setupCopyGroup(group) {
    var copyButton = group.querySelector('.copy-md-btn');
    var toggle = group.querySelector('.copy-md-toggle');
    var dropdown = group.querySelector('.copy-md-dropdown');
    var dropdownCopy = dropdown ? dropdown.querySelector('[data-action="copy"]') : null;

    function setDropdownOpen(open) {
      if (!dropdown || !toggle) {
        return;
      }

      dropdown.setAttribute('aria-hidden', String(!open));
      toggle.setAttribute('aria-expanded', String(open));
    }

    function isDropdownOpen() {
      return Boolean(dropdown && dropdown.getAttribute('aria-hidden') === 'false');
    }

    if (copyButton) {
      copyButton.addEventListener('click', function () {
        copyPageMarkdown(copyButton);
      });
    }

    if (toggle && dropdown) {
      toggle.addEventListener('click', function (event) {
        event.stopPropagation();
        setDropdownOpen(!isDropdownOpen());
      });
    }

    if (dropdownCopy) {
      dropdownCopy.addEventListener('click', function () {
        setDropdownOpen(false);
        copyPageMarkdown(copyButton);
      });
    }

    document.addEventListener('click', function (event) {
      if (!dropdown || !toggle || !isDropdownOpen()) {
        return;
      }
      if (!dropdown.contains(event.target) && !toggle.contains(event.target)) {
        setDropdownOpen(false);
      }
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && dropdown && toggle && isDropdownOpen()) {
        setDropdownOpen(false);
        toggle.focus();
      }
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.copy-md-group').forEach(setupCopyGroup);
  });
})();
