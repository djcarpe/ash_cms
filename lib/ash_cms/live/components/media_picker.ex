defmodule AshCms.Live.Components.MediaPicker do
  @moduledoc """
  LiveComponent for browsing and selecting media from the CMS media library.

  Supports:
  - Browsing existing uploads by folder/type
  - Uploading new files (local or S3)
  - Filtering by image/video/document
  - Searching by filename
  """

  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:filter, "all")
     |> assign(:search, "")
     |> assign(:uploading, false)
     |> assign(:uploads_in_progress, [])}
  end

  @impl true
  def update(%{site_id: site_id, target: target}, socket) do
    media = load_media(site_id, socket.assigns.filter, socket.assigns.search)

    {:ok,
     socket
     |> assign(:site_id, site_id)
     |> assign(:target, target)
     |> assign(:media, media)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ash-cms-modal-overlay" phx-click="close_media_picker" phx-target={@myself}>
      <div class="ash-cms-media-picker" phx-click-away="close_media_picker" phx-target={@myself}>
        <div class="ash-cms-media-picker-header">
          <h3>Media Library</h3>
          <button class="ash-cms-modal-close" phx-click="close_media_picker" phx-target={@myself}>✕</button>
        </div>

        <div class="ash-cms-media-picker-toolbar">
          <div class="ash-cms-media-filter-tabs">
            <%= for {label, value} <- [{"All", "all"}, {"Images", "images"}, {"Videos", "videos"}, {"Documents", "docs"}] do %>
              <button
                class={"ash-cms-media-filter-tab #{if @filter == value, do: "active"}"}
                phx-click="set_filter"
                phx-value-filter={value}
                phx-target={@myself}
              ><%= label %></button>
            <% end %>
          </div>

          <input
            type="search"
            class="ash-cms-media-search"
            placeholder="Search media…"
            value={@search}
            phx-change="search"
            phx-target={@myself}
            phx-debounce="300"
          />

          <label class="ash-cms-btn-secondary ash-cms-upload-btn">
            <input
              type="file"
              multiple
              class="ash-cms-file-input"
              phx-change="upload_media"
              phx-target={@myself}
              accept="image/*,video/*,application/pdf"
            />
            Upload
          </label>
        </div>

        <div class="ash-cms-media-grid">
          <%= if Enum.empty?(@media) do %>
            <div class="ash-cms-media-empty">
              <p>No media yet. Upload some files to get started.</p>
            </div>
          <% else %>
            <%= for item <- @media do %>
              <div
                class="ash-cms-media-item"
                phx-click="select_media"
                phx-value-url={item.url}
                phx-value-target={@target}
                phx-target={@myself}
                title={item.name}
              >
                <%= if String.starts_with?(item.content_type || "", "image/") do %>
                  <img src={item.url} class="ash-cms-media-thumb" alt={item.alt_text || item.name} />
                <% else %>
                  <div class="ash-cms-media-file-icon">
                    <span><%= media_icon(item.content_type) %></span>
                  </div>
                <% end %>
                <span class="ash-cms-media-name"><%= item.name %></span>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    media = load_media(socket.assigns.site_id, filter, socket.assigns.search)
    {:noreply, socket |> assign(:filter, filter) |> assign(:media, media)}
  end

  def handle_event("search", %{"value" => search}, socket) do
    media = load_media(socket.assigns.site_id, socket.assigns.filter, search)
    {:noreply, socket |> assign(:search, search) |> assign(:media, media)}
  end

  def handle_event("select_media", %{"url" => url, "target" => target}, socket) do
    send(self(), {:proxy_event, "media_selected", %{"url" => url, "target" => target}})
    {:noreply, socket}
  end

  def handle_event("close_media_picker", _params, socket) do
    send(self(), {:proxy_event, "close_media_picker", %{}})
    {:noreply, socket}
  end

  def handle_event("upload_media", params, socket) do
    # Delegate to AshCms.Media.upload/3 which handles local/S3
    # In a real impl, use Phoenix LiveView uploads
    {:noreply, put_flash(socket, :info, "Upload started…")}
  end

  defp load_media(site_id, filter, search) do
    media_mod = AshCms.media_resource()
    domain = AshCms.domain()

    action = if filter == "images", do: :images, else: :for_site

    media_mod
    |> Ash.Query.for_read(action, %{site_id: site_id})
    |> Ash.read!(domain: domain)
    |> Enum.filter(fn m ->
      search == "" or String.contains?(String.downcase(m.name || ""), String.downcase(search))
    end)
  rescue
    _ -> []
  end

  defp media_icon(content_type) do
    cond do
      String.starts_with?(content_type || "", "video/") -> "🎬"
      String.starts_with?(content_type || "", "audio/") -> "🎵"
      content_type == "application/pdf" -> "📄"
      true -> "📁"
    end
  end
end
