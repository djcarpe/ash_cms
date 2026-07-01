# AshCms

[![Hex version badge](https://img.shields.io/hexpm/v/ash_cms.svg)](https://hex.pm/packages/ash_cms)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ash_cms/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir CI](https://github.com/your_org/ash_cms/actions/workflows/elixir.yml/badge.svg)](https://github.com/your_org/ash_cms/actions/workflows/elixir.yml)

AshCms is a **full-featured Content Management System extension for the [Ash Framework](https://ash-hq.org)**. It gives you drag-and-drop visual editing, a live code editor powered by Monaco (the VS Code engine), multi-site support, and real-time page updates over Phoenix PubSub — all wired into the Ash resource lifecycle you already know.

> Think of AshCms as the CMS layer that fits _inside_ your Ash application rather than sitting beside it. Your pages are Ash resources. Your components are Ash resources. Authorization, validations, calculations, and extensions all work exactly as they do on every other resource in your domain.

---

## What AshCms provides

**A visual block editor.** Pages are composed of blocks — Hero, Text, Image, Video, Columns, Button, and more. Drag to reorder. Click to configure. No page reload required.

**A live code editor.** Switch any page to code mode and write HEEx directly in Monaco with real-time preview. Great for developers who want full control without leaving the CMS.

**User-defined components.** Define reusable blocks as HEEx templates stored in your database, complete with a JSON-schema-driven properties panel auto-generated from your spec. Register a `feature_card` component and it appears alongside built-in blocks in every editor on that site.

**Distributed page routing via `Group`.** Uses [Chris McCord's `group` library](https://hex.pm/packages/group) to maintain a cluster-wide registry of published pages. The router's catch-all route looks up the current path in this registry — no database query on the hot path. When a page is published, a `PageServer` GenServer registers itself. When unpublished, it stops. The registry stays consistent across nodes automatically.

**Full LiveView lifecycle.** Pages are rendered by `AshCms.Live.PageLive`. Visitors get a real-time connection. When you publish a change in the editor, every connected browser re-renders the page via PubSub — no manual broadcast code required.

**S3-compatible media library.** Upload images, video, and documents to local storage or S3. The media picker is available in every block's properties panel.

**Any data layer.** AshCms ships resource attribute and action mixins rather than concrete resource definitions. You bring your own resource modules and choose `AshSqlite.DataLayer`, `AshPostgres.DataLayer`, or anything else that implements the Ash data layer behaviour.

**Igniter installer.** Run one command and get working resource modules, migrations, router wiring, and config — ready to customise.

---

## Installation

### Using Igniter (recommended)

```bash
mix igniter.install ash_cms
```

This creates your CMS resource modules, configures the application, adds `AshCms.CMSSupervisor` to your supervision tree, and wires the router in a single step.

### Manual

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ash_cms, "~> 0.1"},

    # Optional: one-command installer
    {:igniter, "~> 0.5", only: :dev},

    # Optional: S3 media storage
    {:ex_aws, "~> 2.5", optional: true},
    {:ex_aws_s3, "~> 2.5", optional: true},
    {:hackney, "~> 1.9", optional: true}
  ]
end
```

---

## Quick start (manual setup)

### 1. Configure your application

```elixir
# config/config.exs
config :ash_cms,
  domain: MyApp.CMS,
  site_resource: MyApp.CMS.Site,
  page_resource: MyApp.CMS.Page,
  component_resource: MyApp.CMS.Component,
  layout_resource: MyApp.CMS.Layout,
  media_resource: MyApp.CMS.Media,
  endpoint: MyAppWeb.Endpoint,
  pubsub_server: MyApp.PubSub,
  media_storage: :local,        # or :s3
  upload_dir: "priv/static/uploads"
```

For S3 storage:

```elixir
config :ash_cms,
  media_storage: :s3,
  s3_bucket: "my-cms-assets",
  s3_prefix: "media"

config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}],
  region: "us-east-1"
```

### 2. Create your CMS domain

```elixir
defmodule MyApp.CMS do
  use Ash.Domain, extensions: [AshCms.DomainExtension]

  ash_cms do
    pubsub_server MyApp.PubSub
    endpoint MyAppWeb.Endpoint

    site "My Site" do
      slug "main"
      domain "mysite.com"   # optional — enables hostname-based routing
      css_url "/assets/site.css"
    end
  end

  resources do
    resource MyApp.CMS.Site
    resource MyApp.CMS.Page
    resource MyApp.CMS.Component
    resource MyApp.CMS.Layout
    resource MyApp.CMS.Media
  end
end
```

### 3. Create your CMS resources

AshCms provides attribute and action mixins. Bring your own data layer:

```elixir
defmodule MyApp.CMS.Page do
  use Ash.Resource,
    domain: MyApp.CMS,
    data_layer: AshSqlite.DataLayer

  use AshCms.Resource.PageAttributes

  sqlite do
    table "cms_pages"
    repo MyApp.Repo
  end

  relationships do
    belongs_to :site, MyApp.CMS.Site, allow_nil?: false, attribute_writable?: true
    belongs_to :layout, MyApp.CMS.Layout, allow_nil?: true, attribute_writable?: true
  end
end
```

The same pattern applies to `Site`, `Component`, `Layout`, and `Media` — each has a corresponding `AshCms.Resource.*Attributes` mixin. See the [example app](example/) for complete definitions of all five resources.

### 4. Add the router

```elixir
defmodule MyAppWeb.Router do
  use Phoenix.Router
  import AshCms.Router

  pipeline :browser do
    # ...
  end

  # CMS admin panel — protect this with your auth pipeline in production
  ash_cms_admin_routes("/cms")

  scope "/", MyAppWeb do
    pipe_through :browser
    # ... your own routes ...

    # CMS page catch-all — must come last
    ash_cms_routes()
  end
end
```

### 5. Add the supervisor

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    MyAppWeb.Endpoint,
    AshCms.CMSSupervisor   # starts a PageServer for every published page
  ]
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

### 6. Add the JavaScript hooks and CSS

In `assets/js/app.js`:

```javascript
import { AshCmsHooks } from "../../deps/ash_cms/priv/static/ash_cms.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...AshCmsHooks, ...YourOwnHooks }
})
```

In `assets/css/app.css`:

```css
@import "../../deps/ash_cms/priv/static/ash_cms.css";
```

### 7. Run migrations and start

```bash
mix ash.migrate
mix phx.server
```

Visit `http://localhost:4000/cms` to open the admin panel.

---

## The editor

### Visual mode

The visual editor is a three-panel layout:

```
┌──────────────┬────────────────────────────┬─────────────────┐
│  COMPONENTS  │          CANVAS            │   PROPERTIES    │
│              │                            │                 │
│ Layout:      │ ⠿ Hero Block          ✕   │ Hero Banner     │
│  Hero        │   "Welcome to My Site"     │                 │
│  Columns     │                            │ Title           │
│              │ ⠿ Text Block          ✕   │ [text input]    │
│ Content:     │   Lorem ipsum...           │                 │
│  Text        │                            │ Subtitle        │
│  Button      │ ⠿ Image Block         ✕   │ [text input]    │
│  HTML        │   [image preview]          │                 │
│              │                            │ Height          │
│ Custom:      │ [ + Add Block ]            │ [large ▾]       │
│  MyCard      │                            │                 │
└──────────────┴────────────────────────────┴─────────────────┘
```

Blocks are reordered by dragging the ⠿ handle (powered by [SortableJS](https://sortablejs.com/)). The Properties Panel is driven by the block's `props_schema` — no extra code needed.

### Code mode

Switch any page to code mode to write raw HEEx with a live preview pane:

```
┌──────────────────────────┬─────────────────────────────┐
│  Monaco Editor           │  Live Preview               │
│                          │                             │
│  <section class="hero">  │  ┌───────────────────────┐  │
│    <h1>Welcome</h1>      │  │   Welcome              │  │
│    <p>Subtitle</p>       │  │   Subtitle             │  │
│  </section>              │  └───────────────────────┘  │
│                          │                             │
│  <div class="prose">     │  Lorem ipsum...             │
│    <p>Content here.</p>  │                             │
│  </div>                  │                             │
└──────────────────────────┴─────────────────────────────┘
```

Available assigns in code-mode templates: `@page`, `@site`.

---

## Built-in block types

| Type | Description | Props |
|------|-------------|-------|
| `hero` | Full-width banner with title, subtitle, and CTA button | title, subtitle, button_text, button_url, background_color, text_color, height, align |
| `text` | Rich HTML content area | content (richtext), css_class |
| `image` | Responsive image with optional caption | src (media), alt, caption, width, align |
| `video` | Embedded or hosted video | src, type (url/youtube/vimeo/upload), poster, autoplay, loop, controls |
| `columns` | Grid layout with 2–4 equal columns | count, gap |
| `button` | CTA link button | text, url, variant, size, align, open_in_new_tab |
| `divider` | Horizontal rule | style, color, thickness, margin |
| `html` | Raw HTML passthrough | content (code editor) |
| `spacer` | Vertical whitespace | height, responsive_hidden |

### Registering custom block types at runtime

```elixir
AshCms.Blocks.register(%{
  type: "pricing_table",
  name: "Pricing Table",
  icon: "table-cells",
  category: "content",
  default_props: %{
    "title" => "Simple pricing",
    "plans" => []
  },
  props_schema: %{
    "title" => %{"type" => "string", "label" => "Section Title"},
    "plans" => %{"type" => "richtext", "label" => "Plans (HTML)"}
  }
})
```

Custom block types registered at runtime appear in the component palette immediately.

---

## User-defined components

Create a component through the admin panel at `/cms/sites/:site_id/components` or via Ash actions:

```elixir
Ash.create!(MyApp.CMS.Component, %{
  name: "Feature Card",
  slug: "feature_card",
  category: "content",
  site_id: site.id,
  props_schema: %{
    "icon"        => %{"type" => "string", "label" => "Icon (emoji)"},
    "title"       => %{"type" => "string", "label" => "Title"},
    "description" => %{"type" => "richtext", "label" => "Description"},
    "link"        => %{"type" => "string", "label" => "Link URL"},
    "link_text"   => %{"type" => "string", "label" => "Link Text"}
  },
  default_props: %{
    "icon" => "⚡",
    "title" => "Feature",
    "description" => "Describe this feature.",
    "link" => "#",
    "link_text" => "Learn more"
  },
  template: """
  <div class="feature-card">
    <div class="feature-icon"><%= @props["icon"] %></div>
    <h3><%= @props["title"] %></h3>
    <p><%= @props["description"] %></p>
    <a href="<%= @props["link"] %>"><%= @props["link_text"] %> →</a>
  </div>
  """
}, domain: MyApp.CMS)
```

The component appears in the palette under "Your Components" immediately and becomes available in every page editor for that site.

---

## Page routing and the `Group` registry

Page routing works without a database query on the hot path. Here is the full chain:

1. On boot, `AshCms.CMSSupervisor` loads all published pages and starts one `AshCms.PageServer` GenServer for each.
2. Each `PageServer` calls `AshCms.Registry.register/2`, which calls `Group.register/4` to claim the key `"site:my-site/page:about"` cluster-wide.
3. An incoming request hits the `ash_cms_routes()` catch-all. `AshCms.Live.PageLive` extracts the path, calls `Group.lookup/3`, and gets back the `{pid, meta}` of the correct `PageServer`.
4. `PageLive` calls `PageServer.get_page/1` to retrieve the cached page struct and renders it.
5. `PageLive` subscribes to `"ash_cms:page:<id>"`. When the editor saves and publishes a change, `PageServer` broadcasts on that topic and every connected `PageLive` re-renders in place.

Domain-based routing (e.g. `mysite.com`) is supported alongside slug-based routing. If a `Site` has a `domain` set, pages are also registered under `"domain:mysite.com/page:about"` so hostname lookups work transparently.

---

## PubSub events

| Topic | Event | Payload |
|-------|-------|---------|
| `"ash_cms:page:<id>"` | `:page_updated` | `page` |
| `"ash_cms:page:<id>"` | `:page_published` | `page` |
| `"ash_cms:page:<id>"` | `:page_unpublished` | `page` |
| `"ash_cms:site:<id>"` | `:page_updated` | `page` |
| `"ash_cms:site:<id>"` | `:page_published` | `page` |
| `"ash_cms:global"` | `:component_updated` | `component` |

Subscribe in any LiveView:

```elixir
Phoenix.PubSub.subscribe(MyApp.PubSub, AshCms.page_topic(page.id))

def handle_info({:page_updated, page}, socket) do
  {:noreply, assign(socket, :page, page)}
end
```

---

## Layouts

A layout wraps page content with a shared header, footer, or navigation. Use `<%= @inner_content %>` where the page body should appear:

```elixir
Ash.create!(MyApp.CMS.Layout, %{
  name: "Default",
  slug: "default",
  is_default: true,
  site_id: site.id,
  template: """
  <header>
    <a href="/"><%= @site.name %></a>
  </header>

  <main>
    <%= @inner_content %>
  </main>

  <footer>© <%= Date.utc_today().year %> <%= @site.name %></footer>
  """
}, domain: MyApp.CMS)
```

Available assigns in layout templates: `@inner_content`, `@page`, `@site`.

---

## Documentation

### 🎓 Tutorials

- [Getting started with AshCms](documentation/tutorials/getting-started.md) — install, configure, and publish your first page
- [Building a multi-site CMS](documentation/tutorials/multi-site.md) — domain-based routing and per-site themes
- [Writing custom components](documentation/tutorials/custom-components.md) — HEEx templates, props schemas, and the properties panel

### 🔧 How-to guides

- [Add authentication to the admin panel](documentation/how-to/auth.md)
- [Use Postgres instead of SQLite](documentation/how-to/postgres.md)
- [Upload media to S3](documentation/how-to/s3-media.md)
- [Register a custom block type](documentation/how-to/custom-blocks.md)
- [Seed pages programmatically](documentation/how-to/seed-pages.md)
- [Deploy to Fly.io with a clustered Group registry](documentation/how-to/deploy-cluster.md)

### 📚 Reference

- [AshCms on HexDocs](https://hexdocs.pm/ash_cms)
- [DSL Reference — `ash_cms do...end`](documentation/dsls/DSL-AshCms-DomainExtension.md)
- [Resource mixins](documentation/dsls/resource-mixins.md)
- [`AshCms.Blocks`](documentation/reference/blocks.md) — built-in block types and the registration API
- [`AshCms.Renderer`](documentation/reference/renderer.md) — block-to-HTML rendering pipeline
- [`AshCms.Registry`](documentation/reference/registry.md) — Group-based page registry API
- [`AshCms.Router`](documentation/reference/router.md) — `ash_cms_routes/1` and `ash_cms_admin_routes/2`
- [JavaScript hooks](documentation/reference/js-hooks.md) — `AshCMSEditor`, `AshCMSBlockList`, `AshCMSMonaco`

### 💡 Explanations

- [Architecture overview](documentation/topics/architecture.md) — how the editor, registry, renderer, and PubSub fit together
- [Page content model](documentation/topics/content-model.md) — the block AST, visual vs. code mode, and the `template` field
- [The Group registry](documentation/topics/group-registry.md) — why a distributed process registry instead of a database lookup
- [How rendering works](documentation/topics/rendering.md) — block rendering, layout wrapping, custom components
- [Comparison with BeaconCMS](documentation/topics/comparison.md)

---

## Example application

The [`example/`](example/) directory contains a complete Phoenix + SQLite application demonstrating all CMS features:

```
example/
├── lib/
│   ├── example/cms/          # All five resource modules (Site, Page, Component, Layout, Media)
│   └── example_web/          # Phoenix endpoint, router with ash_cms_routes(), layouts
└── priv/repo/seeds.exs       # Seeds a demo site with 3 published pages
```

To run it:

```bash
cd example
mix deps.get
mix ash.migrate          # generates and runs SQLite migrations
mix run priv/repo/seeds.exs
mix phx.server
```

| URL | Description |
|-----|-------------|
| `http://localhost:4000/cms` | Admin dashboard |
| `http://localhost:4000/demo/home` | Home page (visual mode — hero + columns + feature cards) |
| `http://localhost:4000/demo/about` | About page (visual mode — hero + rich text) |
| `http://localhost:4000/demo/blog` | Blog page (code mode — raw HEEx) |

---

## Contributing

We welcome pull requests. Fork the repository, make your changes on a branch, and open a PR against `main`.

- Commit messages should follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
- For questions or design discussions, find us in the `#ash-cms` channel on the [Ash Discord](https://discord.gg/HTHRaaVPUc).

---

## Acknowledgements

AshCms builds on the shoulders of the Ash ecosystem. Special thanks to:

- The [Ash Framework](https://ash-hq.org) team for the resource model and Spark DSL system
- [Chris McCord](https://github.com/chrismccord) for the [`group`](https://hex.pm/packages/group) distributed registry library
- The Phoenix team for LiveView, PubSub, and the LiveView upload system
- The Monaco Editor team for the VS Code editing engine

---

## License

AshCms is released under the [MIT License](LICENSE).
