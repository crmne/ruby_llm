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

const earlyChunks = new Map()
const removedReplies = new Set()
const chatStream = "turbo-cable-stream-source[data-chat-stream]"
let visiting = false

addEventListener("turbo:visit", () => { visiting = true })
addEventListener("turbo:load", () => { visiting = false })

addEventListener("turbo:before-stream-render", (event) => {
  const render = event.detail.render
  event.detail.render = (stream) => {
    if (stream.getAttribute("action") === "remove") removedReplies.add(stream.getAttribute("target"))
    if (holdsRefresh(stream, render)) return
    if (!holdsEarlyChunk(stream) && !revivesPlaceholder(stream)) render(stream)
  }
})

// A chat page refreshes whenever its stream connects, so it shows what was
// broadcast before it subscribed or while it was offline, such as a reply
// that failed at once. The refresh morphs whatever the page's own refresh
// method, so the stream stays connected and the refresh happens once.
const catchUp = '<turbo-stream action="refresh" method="morph" scroll="preserve"></turbo-stream>'

new MutationObserver((records) => {
  for (const { target } of records) {
    if (target.matches(`${chatStream}[connected]`)) target.dispatchEvent(new MessageEvent("message", { data: catchUp }))
  }
}).observe(document.documentElement, { subtree: true, attributeFilter: ["connected"] })

addEventListener("turbo:before-morph-element", (event) => {
  const { newElement } = event.detail
  const currentElement = event.detail.currentElement ?? event.target
  const removesStreamingReply = !newElement && currentElement.hasAttribute?.("data-streaming")
  if (removesStreamingReply || newElement?.hasAttribute?.("data-streaming")) event.preventDefault()
  if (changedDraftField(currentElement) && newElement?.id === currentElement.id) event.preventDefault()
})

function changedDraftField(element) {
  if (!element.form?.hasAttribute("data-chat-draft")) return false
  if (element.type === "file") return element.files.length > 0
  if (element.type === "checkbox") return element.checked !== element.defaultChecked
  if (element.type === "radio") return changedRadioGroup(element)
  if (element.options) return changedSelect(element)
  return "defaultValue" in element && element.value !== element.defaultValue
}

function changedRadioGroup(radio) {
  return [...radio.form.elements].some((field) =>
    field.type === "radio" && field.name === radio.name && field.checked !== field.defaultChecked)
}

function changedSelect(select) {
  const options = [...select.options]
  if (select.multiple || select.size > 1) return options.some((option) => option.selected !== option.defaultSelected)

  const rendered = options.findLast((option) => option.defaultSelected) ?? options.find(selectableOption)
  return select.selectedIndex !== (rendered?.index ?? -1)
}

function selectableOption(option) {
  return !option.disabled && !option.closest("optgroup")?.disabled
}

function holdsEarlyChunk(stream) {
  const target = stream.getAttribute("target")
  if (stream.getAttribute("action") !== "append" || !target?.endsWith("_stream")) return false
  if (document.getElementById(target)) return false
  if (document.getElementById(target.replace(/_stream$/, "_content"))) return true

  earlyChunks.set(target, [...(earlyChunks.get(target) ?? []), stream.templateContent])
  return true
}

function revivesPlaceholder(stream) {
  const incoming = stream.templateContent?.firstElementChild
  if (!incoming?.hasAttribute("data-streaming")) return false
  return document.getElementById(incoming.id) !== null || removedReplies.has(incoming.id)
}

// Turbo drops a refresh that arrives during a visit, though the page the
// visit brings may predate it, so a chat page refreshes once the visit ends.
function holdsRefresh(stream, render) {
  if (stream.getAttribute("action") !== "refresh" || !visiting || !document.querySelector(chatStream)) return false

  addEventListener("turbo:load", () => render(stream), { once: true })
  return true
}

export default class extends Controller {
  static targets = ["source", "output"]

  connect() {
    this.observer = new MutationObserver(() => this.update())
    this.observer.observe(this.sourceTarget, { childList: true, characterData: true, subtree: true })
    earlyChunks.get(this.sourceTarget.id)?.forEach((chunk) => this.sourceTarget.append(chunk))
    earlyChunks.delete(this.sourceTarget.id)
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
      if (index > 0 && chunk.dataset.after !== chunks[index - 1].dataset.seq) break
      text += chunk.textContent
    }
    return text
  }
}
