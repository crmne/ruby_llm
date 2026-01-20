(function () {
  function isClipboardAvailable() {
    return Boolean(
      window.isSecureContext &&
      window.navigator &&
      window.navigator.clipboard &&
      window.navigator.clipboard.writeText
    );
  }

  function normalizeUrl(base, path) {
    if (!base || !path) {
      return null;
    }
    var trimmedBase = base.replace(/\/+$/, '');
    var trimmedPath = path.replace(/^\/+/, '');
    return trimmedBase + '/' + trimmedPath;
  }

  function setButtonLabel(button, label) {
    button.textContent = label;
  }

  function restoreLabelAfterDelay(button, label, delay) {
    window.setTimeout(function () {
      if (!button.dataset || button.dataset.isBusy === 'true') {
        return;
      }
      setButtonLabel(button, label);
    }, delay);
  }

  function setupButton(button) {
    var base = button.dataset.markdownBase;
    var path = button.dataset.markdownPath;
    var defaultLabel = button.dataset.labelDefault || 'Copy page';
    var successLabel = button.dataset.labelSuccess || 'Copied';
    var errorLabel = button.dataset.labelError || 'Copy failed';

    setButtonLabel(button, defaultLabel);

    if (!isClipboardAvailable()) {
      button.disabled = true;
      button.title = 'Clipboard copy requires a secure context (HTTPS).';
      return;
    }

    var sourceUrl = normalizeUrl(base, path);
    if (!sourceUrl) {
      button.disabled = true;
      button.title = 'Missing markdown source configuration.';
      return;
    }

    window.fetch(sourceUrl, { cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) {
          throw new Error('Failed to fetch markdown source.');
        }
        return response.text();
      })
      .then(function (markdown) {
        button.dataset.markdownSource = markdown;
      })
      .catch(function () {
        button.dataset.markdownSource = '';
      });

    button.addEventListener('click', function () {
      if (button.dataset.isBusy === 'true') {
        return;
      }

      button.dataset.isBusy = 'true';
      button.disabled = true;
      setButtonLabel(button, 'Copying...');

      var cachedMarkdown = button.dataset.markdownSource || '';
      var copyPromise = cachedMarkdown
        ? window.navigator.clipboard.writeText(cachedMarkdown)
        : window.fetch(sourceUrl, { cache: 'no-store' })
          .then(function (response) {
            if (!response.ok) {
              throw new Error('Failed to fetch markdown source.');
            }
            return response.text();
          })
          .then(function (markdown) {
            button.dataset.markdownSource = markdown;
            return window.navigator.clipboard.writeText(markdown);
          });

      copyPromise
        .then(function () {
          setButtonLabel(button, successLabel);
          button.title = 'Copied to clipboard.';
          button.dataset.isBusy = 'false';
          button.disabled = false;
          restoreLabelAfterDelay(button, defaultLabel, 2000);
        })
        .catch(function () {
          setButtonLabel(button, errorLabel);
          button.title = 'Unable to copy markdown.';
          button.dataset.isBusy = 'false';
          button.disabled = false;
          restoreLabelAfterDelay(button, defaultLabel, 2500);
        });
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    var buttons = document.querySelectorAll('.js-copy-page-markdown');
    if (!buttons.length) {
      return;
    }

    buttons.forEach(function (button) {
      setupButton(button);
    });
  });
})();
