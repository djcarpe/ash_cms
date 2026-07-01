/**
 * AshCms JavaScript
 *
 * Provides Phoenix LiveView hooks for:
 *  - AshCMSEditor      — top-level editor container
 *  - AshCMSBlockList   — SortableJS drag-and-drop block list
 *  - AshCMSMonaco      — Monaco Editor (full page code mode)
 *  - AshCMSInlineMonaco — Monaco Editor (prop-level code snippet)
 *  - AshCMSRichText    — contenteditable rich text field
 *
 * Usage in your app.js:
 *
 *   import { AshCmsHooks } from "../../deps/ash_cms/priv/static/ash_cms.js"
 *   // OR after bundling:
 *   import { AshCmsHooks } from "../vendor/ash_cms"
 *
 *   let liveSocket = new LiveSocket("/live", Socket, {
 *     hooks: { ...AshCmsHooks, ...YourOwnHooks }
 *   })
 *
 * Monaco is loaded from a CDN. If you want to self-host, set
 * window.AshCmsMonacoBase = "/path/to/monaco/vs" before importing this file.
 */

// ── SortableJS ────────────────────────────────────────────────────────────────
// Loaded from CDN or bundled. Replace with your bundled import if preferred.
function loadSortable(cb) {
  if (window.Sortable) return cb(window.Sortable)
  const s = document.createElement("script")
  s.src = "https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/Sortable.min.js"
  s.onload = () => cb(window.Sortable)
  document.head.appendChild(s)
}

// ── Monaco loader ─────────────────────────────────────────────────────────────
const MONACO_CDN = window.AshCmsMonacoBase ||
  "https://cdn.jsdelivr.net/npm/monaco-editor@0.48.0/min/vs"

let monacoLoaded = false
let monacoCallbacks = []

function loadMonaco(cb) {
  if (monacoLoaded) return cb()
  monacoCallbacks.push(cb)
  if (monacoCallbacks.length > 1) return // already loading

  // Inject the Monaco loader script
  window.require = { paths: { vs: MONACO_CDN } }
  const script = document.createElement("script")
  script.src = `${MONACO_CDN}/loader.js`
  script.onload = () => {
    require(["vs/editor/editor.main"], () => {
      monacoLoaded = true
      monacoCallbacks.forEach(fn => fn())
      monacoCallbacks = []
    })
  }
  document.head.appendChild(script)
}

// ── Hooks ─────────────────────────────────────────────────────────────────────

const AshCMSEditor = {
  mounted() {
    // Intercept proxy events from LiveComponents
    this.handleEvent("proxy_event", ({ event, params }) => {
      this.pushEvent(event, params)
    })

    // Handle keyboard shortcuts
    this.el.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "s") {
        e.preventDefault()
        this.pushEvent("save", {})
      }
    })
  }
}

const AshCMSBlockList = {
  mounted() {
    loadSortable((Sortable) => {
      this.sortable = Sortable.create(this.el, {
        animation: 150,
        handle: ".ash-cms-drag-handle",
        ghostClass: "ash-cms-block-ghost",
        chosenClass: "ash-cms-block-chosen",
        dragClass: "ash-cms-block-drag",
        onEnd: (evt) => {
          if (evt.oldIndex !== evt.newIndex) {
            this.pushEvent("reorder_blocks", {
              from: evt.oldIndex,
              to: evt.newIndex
            })
          }
        }
      })
    })
  },

  destroyed() {
    if (this.sortable) this.sortable.destroy()
  }
}

const AshCMSMonaco = {
  mounted() {
    const content = this.el.dataset.content || ""
    const language = this.el.dataset.language || "html"

    loadMonaco(() => {
      this.editor = monaco.editor.create(this.el, {
        value: content,
        language: language,
        theme: "vs-dark",
        minimap: { enabled: false },
        lineNumbers: "on",
        fontSize: 14,
        wordWrap: "on",
        automaticLayout: true,
        scrollBeyondLastLine: false,
        tabSize: 2,
        insertSpaces: true,
        formatOnPaste: true,
        formatOnType: false,
        // HEEx-friendly settings
        bracketPairColorization: { enabled: true },
        guides: { bracketPairs: true }
      })

      this.editor.onDidChangeModelContent(() => {
        clearTimeout(this._changeTimer)
        this._changeTimer = setTimeout(() => {
          this.pushEvent("code_changed", { content: this.editor.getValue() })
        }, 250)
      })
    })
  },

  updated() {
    const newContent = this.el.dataset.content
    if (this.editor && this.editor.getValue() !== newContent) {
      // Only update if changed externally (avoid cursor jump)
      const model = this.editor.getModel()
      const position = this.editor.getPosition()
      model.setValue(newContent)
      this.editor.setPosition(position)
    }
  },

  destroyed() {
    if (this.editor) this.editor.dispose()
  }
}

const AshCMSInlineMonaco = {
  mounted() {
    const content = this.el.dataset.content || ""
    const language = this.el.dataset.language || "html"
    const blockId = this.el.dataset.blockId
    const key = this.el.dataset.key

    loadMonaco(() => {
      this.editor = monaco.editor.create(this.el, {
        value: content,
        language: language,
        theme: "vs-dark",
        minimap: { enabled: false },
        lineNumbers: "off",
        fontSize: 13,
        wordWrap: "on",
        automaticLayout: true,
        scrollBeyondLastLine: false,
        tabSize: 2,
        insertSpaces: true
      })

      this.editor.onDidChangeModelContent(() => {
        clearTimeout(this._timer)
        this._timer = setTimeout(() => {
          this.pushEvent("update_prop", {
            block_id: blockId,
            key: key,
            value: this.editor.getValue()
          })
        }, 300)
      })
    })
  },

  destroyed() {
    if (this.editor) this.editor.dispose()
  }
}

const AshCMSRichText = {
  mounted() {
    const blockId = this.el.dataset.blockId
    const key = this.el.dataset.key

    this._onInput = () => {
      clearTimeout(this._timer)
      this._timer = setTimeout(() => {
        this.pushEvent("update_richtext", {
          block_id: blockId,
          key: key,
          value: this.el.innerHTML
        })
      }, 400)
    }

    this.el.addEventListener("input", this._onInput)

    // Simple rich text toolbar
    this._toolbar = createRichTextToolbar(this.el)
    this.el.parentNode.insertBefore(this._toolbar, this.el)
  },

  destroyed() {
    this.el.removeEventListener("input", this._onInput)
    if (this._toolbar) this._toolbar.remove()
  }
}

function createRichTextToolbar(target) {
  const toolbar = document.createElement("div")
  toolbar.className = "ash-cms-richtext-toolbar"

  const commands = [
    { cmd: "bold", label: "B", title: "Bold" },
    { cmd: "italic", label: "I", title: "Italic" },
    { cmd: "underline", label: "U", title: "Underline" },
    { cmd: "insertUnorderedList", label: "•", title: "Bullet List" },
    { cmd: "insertOrderedList", label: "1.", title: "Numbered List" },
    { cmd: "createLink", label: "🔗", title: "Link", prompt: "URL:" }
  ]

  commands.forEach(({ cmd, label, title, prompt: promptMsg }) => {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "ash-cms-richtext-btn"
    btn.innerHTML = label
    btn.title = title
    btn.addEventListener("mousedown", (e) => {
      e.preventDefault()
      if (promptMsg) {
        const url = window.prompt(promptMsg)
        if (url) document.execCommand(cmd, false, url)
      } else {
        document.execCommand(cmd)
      }
      target.dispatchEvent(new Event("input"))
    })
    toolbar.appendChild(btn)
  })

  return toolbar
}

// ── Export ────────────────────────────────────────────────────────────────────

export const AshCmsHooks = {
  AshCMSEditor,
  AshCMSBlockList,
  AshCMSMonaco,
  AshCMSInlineMonaco,
  AshCMSRichText
}

// Default export for convenience
export default AshCmsHooks
