import { Controller } from "@hotwired/stimulus"
import { Marked } from "marked"
import DOMPurify from "dompurify"

const escape = (text) => text.replace(/[&<>"']/g, (character) => `&#${character.charCodeAt(0)};`)

const markdown = new Marked({
  renderer: {
    html: ({ text }) => escape(text),
    image: ({ href, text }) => escape(`[image: ${text}](${href})`)
  }
})

const purify = DOMPurify(window)
const sanitizeOptions = {
  USE_PROFILES: { html: true },
  FORBID_TAGS: ["img", "picture", "source", "video", "audio", "track", "iframe", "input", "form"],
  FORBID_ATTR: ["srcset", "style", "background", "poster", "ping"]
}

addEventListener("turbo:before-stream-render", (event) => {
  const render = event.detail.render
  event.detail.render = (stream) => {
    if (!revivesPlaceholder(stream)) render(stream)
  }
})

addEventListener("turbo:before-morph-element", (event) => {
  const { currentElement, newElement } = event.detail
  const removesStreamingReply = !newElement && currentElement.hasAttribute?.("data-streaming")
  if (removesStreamingReply || newElement?.hasAttribute?.("data-streaming")) event.preventDefault()
})

function revivesPlaceholder(stream) {
  const incoming = stream.templateContent?.firstElementChild
  return incoming?.hasAttribute("data-streaming") && document.getElementById(incoming.id) !== null
}

export default class extends Controller {
  static targets = ["source", "output"]

  connect() {
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.sourceTarget, { childList: true, characterData: true, subtree: true })
    this.restore()
  }

  disconnect() {
    this.observer.disconnect()
    cancelAnimationFrame(this.frame)
  }

  restore() {
    this.sourceTarget.hidden = true
    this.render()
  }

  update() {
    this.frame ||= requestAnimationFrame(() => this.render())
  }

  order() {
    const seen = new Set()
    for (const chunk of this.sourceTarget.querySelectorAll(":scope > [data-seq]")) {
      if (seen.has(chunk.dataset.seq)) chunk.remove()
      seen.add(chunk.dataset.seq)
    }

    const chunks = [...this.sourceTarget.querySelectorAll(":scope > [data-seq]")]
    const sorted = chunks.toSorted((a, b) => a.dataset.seq - b.dataset.seq)
    if (sorted.some((chunk, index) => chunk !== chunks[index])) this.sourceTarget.append(...sorted)
  }

  render() {
    this.frame = null
    if (this.element.hasAttribute("data-streaming")) this.order()
    this.outputTarget.innerHTML = purify.sanitize(markdown.parse(this.text), sanitizeOptions)
  }

  get text() {
    if (!this.element.hasAttribute("data-streaming")) return this.sourceTarget.textContent

    const chunks = [...this.sourceTarget.querySelectorAll(":scope > [data-seq]")]
    let text = ""
    for (const [index, chunk] of chunks.entries()) {
      if (index > 0 && Number(chunk.dataset.seq) !== Number(chunks[index - 1].dataset.seq) + 1) break
      text += chunk.textContent
    }
    return text
  }
}
