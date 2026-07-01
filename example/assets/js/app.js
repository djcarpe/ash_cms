// AshCms Demo App — JavaScript entry point

import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// Import AshCms hooks and CSS
import { AshCmsHooks } from "../../priv/static/ash_cms.js"

// App-specific hooks (add your own here)
const Hooks = {}

// Combined hooks
const AllHooks = { ...AshCmsHooks, ...Hooks }

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: AllHooks
})

// Connect to LiveSocket
liveSocket.connect()
window.liveSocket = liveSocket
