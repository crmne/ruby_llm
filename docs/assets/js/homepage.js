(function () {
  function initDemoVideos(root) {
    root.querySelectorAll("[data-demo-video]").forEach(function (frame) {
      if (frame.dataset.homeBound) return;
      frame.dataset.homeBound = "true";

      var button = frame.querySelector(".home-play-button");
      if (!button) return;

      var video = frame.querySelector(".home-demo-video");

      // No video yet: the play button says so rather than doing nothing.
      if (!video) {
        button.addEventListener("click", function () {
          frame.classList.add("is-coming-soon");
        });
        return;
      }

      button.addEventListener("click", function () {
        frame.classList.add("is-playing");
        video.controls = true;
        video.play();
      });

      video.addEventListener("ended", function () {
        frame.classList.remove("is-playing");
        video.controls = false;
        video.currentTime = 0;
      });
    });
  }

  function setRunLabel(button, label, showIcon) {
    button.textContent = "";
    if (showIcon) {
      var icon = document.createElement("span");
      icon.setAttribute("aria-hidden", "true");
      button.appendChild(icon);
    }
    button.appendChild(document.createTextNode(label));
  }

  function syncCodeCardDocLink(card) {
    var href = card.dataset.href;
    if (!href) return;

    var wrapper = card.parentElement && card.parentElement.classList.contains("vp-code-block-title")
      ? card.parentElement
      : null;
    var titleBar = wrapper ? wrapper.querySelector(":scope > .vp-code-block-title-bar") : null;
    if (!titleBar) return;

    card.querySelectorAll(":scope > .home-code-card-title-link, :scope > .home-code-card-doc-link").forEach(function (link) {
      link.remove();
    });

    var docTitle = card.dataset.docTitle || "Docs";
    var titleText = titleBar.querySelector(":scope > .vp-code-block-title-text");
    if (!titleText) return;

    var titleLink = titleBar.querySelector(":scope > .home-code-card-title-link");
    if (!titleLink) {
      titleLink = document.createElement("a");
      titleLink.className = "home-code-card-title-link";
      titleBar.replaceChild(titleLink, titleText);
      titleLink.appendChild(titleText);
    } else if (titleText.parentElement !== titleLink) {
      titleLink.textContent = "";
      titleLink.appendChild(titleText);
    }

    titleLink.href = href;
    titleLink.title = "Read " + docTitle + " docs";
    if (card.dataset.title) {
      titleLink.setAttribute("aria-label", "Read " + docTitle + " docs for " + card.dataset.title);
    }
  }

  function initCodeCards(root) {
    root.querySelectorAll(".home-code-card").forEach(function (card) {
      syncCodeCardDocLink(card);

      if (card.dataset.codeBound) return;
      card.dataset.codeBound = "true";

      var code = card.querySelector("pre code");
      var result = card.querySelector(".home-code-result");
      var runButton = card.querySelector(".home-run-button");
      var copyButton = card.querySelector(".home-copy-button");
      if (code && !code.dataset.originalText) {
        code.dataset.originalText = code.textContent.trim();
      }

      if (runButton && code && result) {
        runButton.addEventListener("click", function () {
          if (runButton.dataset.state) {
            resetSnippet(code, result, runButton);
            return;
          }
          runSnippet(code, result, runButton);
        });
      }

      if (copyButton && code) {
        copyButton.addEventListener("click", function () {
          var text = code.dataset.originalText || code.textContent.trim();
          writeClipboard(text).then(function () {
            copyButton.classList.add("is-copied");
            window.setTimeout(function () {
              copyButton.classList.remove("is-copied");
            }, 1200);
          });
        });
      }
    });
  }

  function syncCodeCardDocLinks(root) {
    root.querySelectorAll(".home-code-card").forEach(syncCodeCardDocLink);
  }

  function initModelSwitcher(root) {
    var switcher = root.querySelector("[data-model-switcher]");
    if (!switcher || switcher.dataset.modelSwitcherBound) return;
    switcher.dataset.modelSwitcherBound = "true";

    var card = switcher.querySelector("[data-model-switcher-code]");
    var code = card && card.querySelector("code");
    var model = switcher.querySelector("[data-model-switcher-model]");
    var provider = switcher.querySelector("[data-model-switcher-provider]");
    if (!card || !code) return;

    if (!model || !provider) {
      var stringSpan = Array.prototype.find.call(code.querySelectorAll(".s2"), function (span) {
        return span.textContent.indexOf("claude-opus-4-7") !== -1;
      });
      if (!stringSpan) return;

      stringSpan.textContent = "";
      stringSpan.appendChild(document.createTextNode("\""));

      model = document.createElement("span");
      model.className = "home-model-switcher-model";
      model.dataset.modelSwitcherModel = "";
      stringSpan.appendChild(model);
      stringSpan.appendChild(document.createTextNode("\""));

      provider = document.createElement("span");
      provider.className = "home-model-switcher-provider";
      provider.dataset.modelSwitcherProvider = "";
      stringSpan.parentNode.insertBefore(provider, stringSpan.nextSibling);
    }

    var examples = [
      {
        model: "claude-opus-4-7",
        provider: "",
        title: "Anthropic"
      },
      {
        model: "claude-opus-4-7",
        provider: ', <span class="ss">provider:</span> <span class="ss">:azure</span>',
        title: "Azure AI"
      },
      {
        model: "claude-opus-4-7",
        provider: ', <span class="ss">provider:</span> <span class="ss">:bedrock</span>',
        title: "Amazon Bedrock"
      },
      {
        model: "command-a-plus",
        provider: "",
        title: "Cohere"
      },
      {
        model: "deepseek-v4-pro",
        provider: "",
        title: "DeepSeek"
      },
      {
        model: "gemini-3.1-pro-preview",
        provider: "",
        title: "Gemini"
      },
      {
        model: "qwen3",
        provider: ', <span class="ss">provider:</span> <span class="ss">:gpustack</span>',
        title: "GPUStack"
      },
      {
        model: "mistral-medium-latest",
        provider: "",
        title: "Mistral AI"
      },
      {
        model: "gemma4",
        provider: ', <span class="ss">provider:</span> <span class="ss">:ollama</span>',
        title: "Ollama"
      },
      {
        model: "gpt-5.5",
        provider: "",
        title: "OpenAI"
      },
      {
        model: "claude-opus-4-7",
        provider: ', <span class="ss">provider:</span> <span class="ss">:openrouter</span>',
        title: "OpenRouter"
      },
      {
        model: "sonar-pro",
        provider: "",
        title: "Perplexity"
      },
      {
        model: "gemini-3.1-pro-preview",
        provider: ', <span class="ss">provider:</span> <span class="ss">:vertexai</span>',
        title: "Vertex AI"
      },
      {
        model: "grok-4.3",
        provider: "",
        title: "xAI"
      }
    ];
    var index = 0;
    var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    function render(example) {
      var wrapper = card.parentElement && card.parentElement.classList.contains("vp-code-block-title")
        ? card.parentElement
        : null;
      var title = wrapper && wrapper.querySelector(":scope > .vp-code-block-title-bar .vp-code-block-title-text");

      model.textContent = example.model;
      provider.innerHTML = example.provider;
      card.dataset.title = example.title;
      code.dataset.originalText = code.textContent.trim();
      if (title) {
        title.textContent = example.title;
        title.dataset.title = example.title;
      }
    }

    render(examples[index]);

    if (reduceMotion) return;

    window.setInterval(function () {
      switcher.classList.add("is-swapping");

      window.setTimeout(function () {
        index = (index + 1) % examples.length;
        render(examples[index]);
        switcher.classList.remove("is-swapping");
      }, 180);
    }, 3000);
  }

  function writeClipboard(text) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(text);
    }

    var textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
    return Promise.resolve();
  }

  function resetSnippet(code, result, button) {
    if (result._homeTimer) {
      window.clearTimeout(result._homeTimer);
      result._homeTimer = null;
    }

    if (code.dataset.originalHtml) {
      code.innerHTML = code.dataset.originalHtml;
    }

    button.dataset.state = "";
    setRunLabel(button, "Run", true);
  }

  function appendCommentLine(code, text) {
    var span = document.createElement("span");
    span.className = "c1 home-irb-result";
    span.textContent = text;
    code.appendChild(document.createTextNode("\n"));
    code.appendChild(span);
    return span;
  }

  function runSnippet(code, result, button) {
    var fullText = result.dataset.fullText || result.textContent.trim();
    result.dataset.fullText = fullText;

    if (!code.dataset.originalHtml) code.dataset.originalHtml = code.innerHTML;
    if (!code.dataset.originalText) code.dataset.originalText = code.textContent.trim();
    code.innerHTML = code.dataset.originalHtml;

    button.dataset.state = "running";
    setRunLabel(button, "Running...", false);

    if (!result.hasAttribute("data-stream-result")) {
      fullText.split("\n").forEach(function (line) {
        appendCommentLine(code, "# => " + line);
      });
      button.dataset.state = "done";
      setRunLabel(button, "Reset", false);
      return;
    }

    var output = appendCommentLine(code, "# => ");
    var parts = fullText.split(/(\s+)/);
    var index = 0;

    function tick() {
      output.textContent += parts[index] || "";
      index += 1;

      if (index < parts.length) {
        result._homeTimer = window.setTimeout(tick, 46);
      } else {
        result._homeTimer = null;
        button.dataset.state = "done";
        setRunLabel(button, "Reset", false);
      }
    }

    tick();
  }

  function initLoveCarousel(root) {
    var carousel = root.querySelector("[data-love-carousel]");
    if (!carousel || carousel.dataset.loveBound) return;

    var cards = Array.prototype.slice.call(carousel.querySelectorAll("[data-love-card]"));
    var previousButton = carousel.querySelector("[data-love-prev]");
    var nextButton = carousel.querySelector("[data-love-next]");
    if (!cards.length) return;

    carousel.dataset.loveBound = "true";

    var pageSize = getPageSize();
    var pageCount = Math.ceil(cards.length / pageSize);
    var page = 0;
    var slots = [
      { x: "-7px", y: "2px", rotate: "-1.4deg" },
      { x: "4px", y: "-3px", rotate: "1deg" },
      { x: "8px", y: "4px", rotate: "-0.8deg" },
      { x: "6px", y: "-1px", rotate: "1.6deg" },
      { x: "-4px", y: "3px", rotate: "-1.1deg" },
      { x: "-8px", y: "-4px", rotate: "0.9deg" },
      { x: "3px", y: "0px", rotate: "-1.7deg" },
      { x: "-6px", y: "5px", rotate: "1.2deg" },
      { x: "7px", y: "-2px", rotate: "-0.6deg" }
    ];

    function getPageSize() {
      if (window.matchMedia("(max-width: 760px)").matches) return 3;
      if (window.matchMedia("(max-width: 1100px)").matches) return 6;
      return 9;
    }

    function render() {
      pageSize = getPageSize();
      pageCount = Math.ceil(cards.length / pageSize);
      if (page >= pageCount) page = pageCount - 1;

      var start = page * pageSize;

      cards.forEach(function (card) {
        card.hidden = true;
        card.setAttribute("aria-hidden", "true");
        card.style.order = "";
      });

      var end = Math.min(start + pageSize, cards.length);

      for (var slot = 0; slot < end - start; slot += 1) {
        var card = cards[start + slot];
        var position = slots[slot];

        card.hidden = false;
        card.removeAttribute("aria-hidden");
        card.style.order = String(slot + 1);
        card.style.setProperty("--home-love-x", position.x);
        card.style.setProperty("--home-love-offset", position.y);
        card.style.setProperty("--home-love-rotate", position.rotate);
      }

      if (previousButton) previousButton.setAttribute("aria-label", "Previous quotes, page " + (page + 1) + " of " + pageCount);
      if (nextButton) nextButton.setAttribute("aria-label", "Next quotes, page " + (page + 1) + " of " + pageCount);
    }

    function move(direction) {
      page = (page + direction + pageCount) % pageCount;
      render();
    }

    if (pageCount > 1 && previousButton && nextButton) {
      carousel.classList.add("is-paged");

      previousButton.addEventListener("click", function () {
        move(-1);
      });

      nextButton.addEventListener("click", function () {
        move(1);
      });
    }

    window.addEventListener("resize", render, { passive: true });
    render();
  }

  function initHomepage() {
    var root = document.querySelector(".VPHome");
    if (!root) return;

    initDemoVideos(root);
    initCodeCards(root);
    initModelSwitcher(root);
    window.setTimeout(function () {
      syncCodeCardDocLinks(root);
    }, 0);
    initLoveCarousel(root);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initHomepage);
  } else {
    initHomepage();
  }

  document.addEventListener("turbo:load", initHomepage);
})();
