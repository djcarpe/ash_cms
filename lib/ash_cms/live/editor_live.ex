defmodule AshCms.Live.EditorLive do
  @moduledoc """
  The CMS page editor LiveView. Provides:

  - **Visual mode**: drag-and-drop block editor with component palette and
    properties panel (like Wix or BeaconCMS)
  - **Code mode**: Monaco Editor (VS Code engine) with real-time HEEx preview

  ## Visual editor layout

      ┌─────────────────────────────────────────────────────────────┐
      │  [Site Name > Page Title]  [Visual|Code]  [Preview] [Save] [Publish]
      ├──────────────┬──────────────────────────────┬───────────────┤
      │  COMPONENTS  │         CANVAS               │  PROPERTIES   │
      │              │                              │               │
      │ Layout:      │ [drag handle] Hero Block ✏  │ Selected:     │
      │  □ Hero      │   Title: "Welcome"           │ Hero Banner   │
      │  □ Columns   │   [+ Add Block below]        │               │
      │              │                              │ Title:        │
      │ Content:     │ [drag handle] Text Block ✏  │ [input]       │
      │  □ Text      │   Lorem ipsum...             │               │
      │  □ Button    │                              │ Subtitle:     │
      │              │ [drag handle] Image Block ✏ │ [input]       │
      │ Media:       │   [img: myimage.jpg]         │               │
      │  □ Image     │                              │ Bg Color:     │
      │  □ Video     │ [ + Add Block ]              │ [color]       │
      │              │                              │               │
      │ Custom:      │                              │               │
      │  □ MyCard    │                              │               │
      └──────────────┴──────────────────────────────┴───────────────┘

  ## Code editor layout

      ┌─────────────────────────────────────────────────────────────┐
      │  [Site Name > Page Title]  [Visual|Code]  [Preview] [Save] [Publish]
      ├─────────────────────────────┬───────────────────────────────┤
      │  Monaco Editor              │  Live Preview                 │
      │                             │                               │
      │  <section class="hero">     │  ┌─────────────────────────┐  │
      │    <h1>Welcome</h1>         │  │     Welcome              │  │
      │    <p>Subtitle here</p>     │  │     Subtitle here        │  │
      │  </section>                 │  └─────────────────────────┘  │
      │  <div class="text">         │                               │
      │    <p>Content...</p>        │  Lorem ipsum...               │
      │  </div>                     │                               │
      └─────────────────────────────┴───────────────────────────────┘
  """

  use Phoenix.LiveView

  import Phoenix.HTML, only: [raw: 1]
  alias Phoenix.LiveView.JS

  require Logger

  @impl true
  def mount(params, _session, socket) do
    site_id = params["site_id"]
    page_id = params["page_id"]
    domain = AshCms.domain()

    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)

    {page, blocks, mode} =
      if page_id do
        page = Ash.get!(AshCms.page_resource(), page_id,
                        domain: domain, load: [:site, :layout])

        blocks = (page.content["blocks"] || []) |> Enum.sort_by(& &1["order"])
        {page, blocks, page.editor_mode || :visual}
      else
        template_page = %{
          title: "New Page",
          slug: "",
          description: "",
          content: %{"version" => "1", "blocks" => []},
          template: "",
          editor_mode: :visual,
          published: false,
          site_id: site_id
        }

        {template_page, [], :visual}
      end

    components =
      AshCms.component_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: site_id})
      |> Ash.read!(domain: domain)

    layouts =
      AshCms.layout_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: site_id})
      |> Ash.read!(domain: domain)

    # Subscribe to component updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshCms.pubsub_server(), AshCms.site_topic(site_id))
      Phoenix.PubSub.subscribe(AshCms.pubsub_server(), AshCms.global_topic())
    end

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:page, page)
     |> assign(:page_id, page_id)
     |> assign(:site_id, site_id)
     |> assign(:blocks, blocks)
     |> assign(:mode, mode)
     |> assign(:selected_block_id, nil)
     |> assign(:components, components)
     |> assign(:layouts, layouts)
     |> assign(:code_content, page[:template] || "")
     |> assign(:preview_html, "")
     |> assign(:saved, false)
     |> assign(:saving, false)
     |> assign(:show_media_picker, false)
     |> assign(:media_picker_target, nil)
     |> assign(:title_input, page[:title] || "New Page")
     |> assign(:slug_input, page[:slug] || "")
     |> assign(:page_errors, %{})
     |> update_preview()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ── Block management ──────────────────────────────────────────────────────────

  @impl true
  def handle_event("add_block", %{"type" => type}, socket) do
    case AshCms.Blocks.new_block(type) do
      {:ok, block} ->
        new_block = Map.put(block, "order", length(socket.assigns.blocks))
        blocks = socket.assigns.blocks ++ [new_block]

        {:noreply,
         socket
         |> assign(:blocks, blocks)
         |> assign(:selected_block_id, new_block["id"])
         |> update_preview()}

      {:error, :unknown_type} ->
        # Check custom components
        case Enum.find(socket.assigns.components, &(&1.slug == type)) do
          nil ->
            {:noreply, put_flash(socket, :error, "Unknown block type: #{type}")}

          component ->
            block = %{
              "id" => generate_id(),
              "type" => type,
              "order" => length(socket.assigns.blocks),
              "props" => component.default_props || %{},
              "children" => []
            }

            blocks = socket.assigns.blocks ++ [block]

            {:noreply,
             socket
             |> assign(:blocks, blocks)
             |> assign(:selected_block_id, block["id"])
             |> update_preview()}
        end
    end
  end

  def handle_event("select_block", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_block_id, id)}
  end

  def handle_event("deselect_block", _params, socket) do
    {:noreply, assign(socket, :selected_block_id, nil)}
  end

  def handle_event("delete_block", %{"id" => id}, socket) do
    blocks =
      socket.assigns.blocks
      |> Enum.reject(&(&1["id"] == id))
      |> reindex_blocks()

    selected =
      if socket.assigns.selected_block_id == id, do: nil, else: socket.assigns.selected_block_id

    {:noreply,
     socket
     |> assign(:blocks, blocks)
     |> assign(:selected_block_id, selected)
     |> update_preview()}
  end

  def handle_event("duplicate_block", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.blocks, &(&1["id"] == id)) do
      nil ->
        {:noreply, socket}

      block ->
        new_block = Map.put(block, "id", generate_id())
        idx = Enum.find_index(socket.assigns.blocks, &(&1["id"] == id))

        blocks =
          socket.assigns.blocks
          |> List.insert_at(idx + 1, new_block)
          |> reindex_blocks()

        {:noreply,
         socket
         |> assign(:blocks, blocks)
         |> assign(:selected_block_id, new_block["id"])
         |> update_preview()}
    end
  end

  def handle_event("reorder_blocks", %{"from" => from, "to" => to}, socket) do
    block = Enum.at(socket.assigns.blocks, from)

    blocks =
      socket.assigns.blocks
      |> List.delete_at(from)
      |> List.insert_at(to, block)
      |> reindex_blocks()

    {:noreply,
     socket
     |> assign(:blocks, blocks)
     |> update_preview()}
  end

  def handle_event("move_block_up", %{"id" => id}, socket) do
    idx = Enum.find_index(socket.assigns.blocks, &(&1["id"] == id))

    if idx && idx > 0 do
      blocks =
        socket.assigns.blocks
        |> swap_at(idx, idx - 1)
        |> reindex_blocks()

      {:noreply, socket |> assign(:blocks, blocks) |> update_preview()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("move_block_down", %{"id" => id}, socket) do
    blocks = socket.assigns.blocks
    idx = Enum.find_index(blocks, &(&1["id"] == id))

    if idx && idx < length(blocks) - 1 do
      new_blocks =
        blocks
        |> swap_at(idx, idx + 1)
        |> reindex_blocks()

      {:noreply, socket |> assign(:blocks, new_blocks) |> update_preview()}
    else
      {:noreply, socket}
    end
  end

  # ── Prop updates ──────────────────────────────────────────────────────────────

  def handle_event("update_prop", %{"block_id" => block_id, "key" => key, "value" => value}, socket) do
    blocks =
      Enum.map(socket.assigns.blocks, fn block ->
        if block["id"] == block_id do
          put_in(block, ["props", key], value)
        else
          block
        end
      end)

    {:noreply,
     socket
     |> assign(:blocks, blocks)
     |> update_preview()}
  end

  def handle_event("update_richtext", %{"block_id" => block_id, "key" => key, "value" => value}, socket) do
    handle_event("update_prop", %{"block_id" => block_id, "key" => key, "value" => value}, socket)
  end

  # ── Editor mode ───────────────────────────────────────────────────────────────

  def handle_event("set_mode", %{"mode" => mode_str}, socket) do
    mode = String.to_existing_atom(mode_str)

    socket =
      case mode do
        :code ->
          # Convert blocks to HEEx on switch to code mode
          html = AshCms.Renderer.render_blocks(
            socket.assigns.blocks,
            socket.assigns.site,
            socket.assigns.components
          )

          socket
          |> assign(:mode, :code)
          |> assign(:code_content, socket.assigns.page[:template] || html)

        :visual ->
          assign(socket, :mode, :visual)
      end

    {:noreply, update_preview(socket)}
  end

  def handle_event("code_changed", %{"content" => content}, socket) do
    {:noreply,
     socket
     |> assign(:code_content, content)
     |> update_preview()}
  end

  # ── Page metadata ─────────────────────────────────────────────────────────────

  def handle_event("update_title", %{"value" => value}, socket) do
    {:noreply, assign(socket, :title_input, value)}
  end

  def handle_event("update_slug", %{"value" => value}, socket) do
    {:noreply, assign(socket, :slug_input, value)}
  end

  # ── Save / Publish ────────────────────────────────────────────────────────────

  def handle_event("save", _params, socket) do
    {:noreply, do_save(socket)}
  end

  def handle_event("publish", _params, socket) do
    socket = do_save(socket)

    case socket.assigns.page do
      %{id: page_id} when not is_nil(page_id) ->
        page_mod = AshCms.page_resource()
        domain = AshCms.domain()

        case Ash.update(socket.assigns.page, %{}, action: :publish, domain: domain) do
          {:ok, page} ->
            {:noreply,
             socket
             |> assign(:page, page)
             |> put_flash(:info, "Page published!")}

          {:error, err} ->
            {:noreply, put_flash(socket, :error, "Publish failed: #{inspect(err)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Save the page first before publishing.")}
    end
  end

  def handle_event("unpublish", _params, socket) do
    page_mod = AshCms.page_resource()
    domain = AshCms.domain()

    case Ash.update(socket.assigns.page, %{}, action: :unpublish, domain: domain) do
      {:ok, page} ->
        {:noreply,
         socket
         |> assign(:page, page)
         |> put_flash(:info, "Page unpublished.")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(err)}")}
    end
  end

  # ── Media picker ──────────────────────────────────────────────────────────────

  def handle_event("open_media_picker", %{"target" => target}, socket) do
    {:noreply,
     socket
     |> assign(:show_media_picker, true)
     |> assign(:media_picker_target, target)}
  end

  def handle_event("close_media_picker", _params, socket) do
    {:noreply, assign(socket, :show_media_picker, false)}
  end

  def handle_event("media_selected", %{"url" => url, "target" => target}, socket) do
    [block_id, prop_key] = String.split(target, ":", parts: 2)

    blocks =
      Enum.map(socket.assigns.blocks, fn block ->
        if block["id"] == block_id, do: put_in(block, ["props", prop_key], url), else: block
      end)

    {:noreply,
     socket
     |> assign(:blocks, blocks)
     |> assign(:show_media_picker, false)
     |> update_preview()}
  end

  # ── PubSub ───────────────────────────────────────────────────────────────────

  # Messages forwarded from LiveComponents via send(self(), ...)
  @impl true
  def handle_info({:update_block_prop, block_id, key, value}, socket) do
    blocks =
      Enum.map(socket.assigns.blocks, fn block ->
        if block["id"] == block_id, do: put_in(block, ["props", key], value), else: block
      end)

    {:noreply, socket |> assign(:blocks, blocks) |> update_preview()}
  end

  def handle_info({:open_media_picker, target}, socket) do
    {:noreply,
     socket
     |> assign(:show_media_picker, true)
     |> assign(:media_picker_target, target)}
  end

  def handle_info({:component_updated, _component}, socket) do
    components =
      AshCms.component_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: socket.assigns.site_id})
      |> Ash.read!(domain: AshCms.domain())

    {:noreply,
     socket
     |> assign(:components, components)
     |> update_preview()}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ash-cms-editor" phx-hook="AshCMSEditor" id="ash-cms-editor">

      <%!-- Top bar --%>
      <div class="ash-cms-editor-topbar">
        <div class="ash-cms-editor-breadcrumb">
          <a href={"/cms/sites/#{@site_id}"} class="ash-cms-editor-site-name"><%= @site.name %></a>
          <span>›</span>
          <input
            type="text"
            value={@title_input}
            placeholder="Page Title"
            class="ash-cms-editor-title-input"
            phx-blur="update_title"
            phx-value-value={@title_input}
            phx-debounce="500"
          />
        </div>

        <div class="ash-cms-editor-slug-row">
          <span class="ash-cms-slug-prefix"><%= @site.domain || @site.slug %>/</span>
          <input
            type="text"
            value={@slug_input}
            placeholder="page-url"
            class="ash-cms-editor-slug-input"
            phx-blur="update_slug"
            phx-value-value={@slug_input}
            phx-debounce="300"
          />
        </div>

        <div class="ash-cms-editor-actions">
          <div class="ash-cms-mode-toggle">
            <button
              class={"ash-cms-mode-btn #{if @mode == :visual, do: "active"}"}
              phx-click="set_mode"
              phx-value-mode="visual"
            >
              Visual
            </button>
            <button
              class={"ash-cms-mode-btn #{if @mode == :code, do: "active"}"}
              phx-click="set_mode"
              phx-value-mode="code"
            >
              Code
            </button>
          </div>

          <button
            class="ash-cms-btn-ghost"
            phx-click={JS.navigate("/cms/sites/#{@site_id}/pages/#{@page_id}/preview")}
          >
            Preview
          </button>

          <button class="ash-cms-btn-secondary" phx-click="save" disabled={@saving}>
            <%= if @saving, do: "Saving…", else: "Save" %>
          </button>

          <%= if @page[:published] do %>
            <button class="ash-cms-btn-warning" phx-click="unpublish">Unpublish</button>
          <% else %>
            <button class="ash-cms-btn-primary" phx-click="publish">Publish</button>
          <% end %>
        </div>
      </div>

      <%!-- Editor body --%>
      <div class="ash-cms-editor-body">
        <%= if @mode == :visual do %>
          <%!-- Left sidebar: Component palette --%>
          <div class="ash-cms-palette">
            <h3 class="ash-cms-palette-title">Components</h3>
            <%= for {category, blocks} <- AshCms.Blocks.grouped() do %>
              <div class="ash-cms-palette-category">
                <h4 class="ash-cms-palette-category-title"><%= String.capitalize(category) %></h4>
                <%= for block_def <- blocks do %>
                  <div
                    class="ash-cms-palette-item"
                    draggable="true"
                    phx-click="add_block"
                    phx-value-type={block_def.type}
                    title={block_def.name}
                  >
                    <span class="ash-cms-palette-icon">
                      <.heroicon name={block_def.icon} />
                    </span>
                    <span class="ash-cms-palette-item-name"><%= block_def.name %></span>
                  </div>
                <% end %>
              </div>
            <% end %>

            <%= if Enum.any?(@components) do %>
              <div class="ash-cms-palette-category">
                <h4 class="ash-cms-palette-category-title">Your Components</h4>
                <%= for component <- @components do %>
                  <div
                    class="ash-cms-palette-item"
                    phx-click="add_block"
                    phx-value-type={component.slug}
                    title={component.description}
                  >
                    <span class="ash-cms-palette-icon">
                      <.heroicon name={component.icon || "squares-2x2"} />
                    </span>
                    <span class="ash-cms-palette-item-name"><%= component.name %></span>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- Center: Canvas --%>
          <div class="ash-cms-canvas" phx-hook="AshCMSBlockList" id="ash-cms-canvas">
            <%= if Enum.empty?(@blocks) do %>
              <div class="ash-cms-canvas-empty">
                <p>Your page is empty. Click a component on the left to add it here.</p>
              </div>
            <% end %>

            <%= for block <- Enum.sort_by(@blocks, & &1["order"]) do %>
              <div
                class={"ash-cms-block-wrapper #{if block["id"] == @selected_block_id, do: "selected"}"}
                id={"block-#{block["id"]}"}
                data-block-id={block["id"]}
                phx-click="select_block"
                phx-value-id={block["id"]}
              >
                <%!-- Block toolbar --%>
                <div class="ash-cms-block-toolbar">
                  <span class="ash-cms-drag-handle" title="Drag to reorder">
                    <.heroicon name="bars-3" />
                  </span>
                  <span class="ash-cms-block-type"><%= block_type_label(block["type"]) %></span>
                  <div class="ash-cms-block-actions">
                    <button
                      phx-click="move_block_up"
                      phx-value-id={block["id"]}
                      title="Move up"
                    >↑</button>
                    <button
                      phx-click="move_block_down"
                      phx-value-id={block["id"]}
                      title="Move down"
                    >↓</button>
                    <button
                      phx-click="duplicate_block"
                      phx-value-id={block["id"]}
                      title="Duplicate"
                    >⎘</button>
                    <button
                      phx-click="delete_block"
                      phx-value-id={block["id"]}
                      title="Delete"
                      class="ash-cms-block-delete"
                      data-confirm="Delete this block?"
                    >✕</button>
                  </div>
                </div>

                <%!-- Block preview --%>
                <div class="ash-cms-block-preview">
                  <%= raw(render_block_preview(block, @site, @components)) %>
                </div>
              </div>
            <% end %>

            <button class="ash-cms-add-first-block" phx-click="add_block" phx-value-type="text">
              + Add Block
            </button>
          </div>

          <%!-- Right sidebar: Properties panel --%>
          <div class="ash-cms-properties">
            <%= if @selected_block_id do %>
              <%= case Enum.find(@blocks, &(&1["id"] == @selected_block_id)) do %>
                <% nil -> %>
                  <p class="ash-cms-properties-empty">Block not found.</p>
                <% block -> %>
                  <.live_component
                    module={AshCms.Live.Components.PropertiesPanel}
                    id={"props-#{block["id"]}"}
                    block={block}
                    components={@components}
                    site_id={@site_id}
                  />
              <% end %>
            <% else %>
              <div class="ash-cms-properties-empty">
                <p>Select a block to edit its properties.</p>
              </div>
            <% end %>
          </div>

        <% else %>
          <%!-- Code editor mode --%>
          <div class="ash-cms-code-editor-wrapper">
            <div
              id="ash-cms-monaco"
              class="ash-cms-monaco-editor"
              phx-hook="AshCMSMonaco"
              data-content={@code_content}
              data-language="html"
            ></div>
            <div class="ash-cms-code-preview">
              <div class="ash-cms-code-preview-header">Live Preview</div>
              <div class="ash-cms-code-preview-body">
                <%= raw(@preview_html) %>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Media Picker Modal --%>
      <%= if @show_media_picker do %>
        <.live_component
          module={AshCms.Live.Components.MediaPicker}
          id="media-picker-modal"
          site_id={@site_id}
          target={@media_picker_target}
        />
      <% end %>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp do_save(socket) do
    socket = assign(socket, :saving, true)
    page_mod = AshCms.page_resource()
    domain = AshCms.domain()

    content = %{"version" => "1", "blocks" => socket.assigns.blocks}

    attrs = %{
      title: socket.assigns.title_input,
      slug: socket.assigns.slug_input,
      content: content,
      template: (if socket.assigns.mode == :code, do: socket.assigns.code_content, else: nil),
      editor_mode: socket.assigns.mode,
      site_id: socket.assigns.site_id
    }

    result =
      case socket.assigns.page_id do
        nil ->
          Ash.create(page_mod, attrs, domain: domain)

        page_id ->
          Ash.update(socket.assigns.page, attrs, domain: domain)
      end

    case result do
      {:ok, page} ->
        socket
        |> assign(:page, page)
        |> assign(:page_id, page.id)
        |> assign(:saving, false)
        |> assign(:saved, true)
        |> put_flash(:info, "Page saved.")

      {:error, err} ->
        Logger.error("[EditorLive] Save failed: #{inspect(err)}")

        socket
        |> assign(:saving, false)
        |> put_flash(:error, "Save failed: #{format_error(err)}")
    end
  end

  defp update_preview(socket) do
    html =
      case socket.assigns.mode do
        :visual ->
          AshCms.Renderer.render_blocks(
            socket.assigns.blocks,
            socket.assigns.site,
            socket.assigns.components
          )

        :code ->
          EEx.eval_string(
            socket.assigns.code_content || "",
            assigns: %{site: socket.assigns.site}
          )
      end

    assign(socket, :preview_html, html)
  rescue
    _ -> assign(socket, :preview_html, "<p class='ash-cms-preview-error'>Template error</p>")
  end

  defp render_block_preview(block, site, components) do
    AshCms.Renderer.render_block(block, site, components)
  rescue
    _ -> ~s(<div class="ash-cms-block-error">Render error</div>)
  end

  defp reindex_blocks(blocks) do
    blocks |> Enum.with_index() |> Enum.map(fn {b, i} -> Map.put(b, "order", i) end)
  end

  defp swap_at(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp block_type_label(type) do
    case AshCms.Blocks.find(type) do
      nil -> type
      def -> def.name
    end
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors |> Enum.map(& &1.message) |> Enum.join(", ")
  end

  defp format_error(err), do: inspect(err)

  # Stub for heroicon helper — users should have their own or use HeroiconsHtml
  defp heroicon(%{name: name} = assigns) do
    ~H"""
    <span class={"hero-icon hero-icon-#{@name}"}></span>
    """
  end
end
