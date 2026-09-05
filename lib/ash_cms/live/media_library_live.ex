defmodule AshCms.Live.MediaLibraryLive do
  @moduledoc "Full media library management LiveView."

  use Phoenix.LiveView

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    domain = AshCms.domain()
    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)
    media = load_media(site_id)

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:site_id, site_id)
     |> assign(:media, media)
     |> assign(:filter, "all")
     |> assign(:search, "")
     |> allow_upload(:files,
       accept: ~w(.jpg .jpeg .png .gif .webp .svg .pdf .mp4 .mov .webm),
       max_entries: 10,
       max_file_size: 50_000_000
     )}
  rescue
    _ -> {:ok, assign(socket, site_id: nil, site: nil, media: [])}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _params, socket) do
    site_id = socket.assigns.site_id
    domain = AshCms.domain()
    media_mod = AshCms.media_resource()

    uploaded_entries =
      consume_uploaded_entries(socket, :files, fn %{path: temp_path}, entry ->
        binary = File.read!(temp_path)
        content_type = entry.client_type

        case AshCms.Media.Uploader.upload(binary, entry.client_name, content_type) do
          {:ok, url, storage_path} ->
            Ash.create!(media_mod, %{
              name: entry.client_name,
              filename: entry.client_name,
              content_type: content_type,
              size: entry.client_size,
              url: url,
              storage_path: storage_path,
              storage_backend: AshCms.Media.Uploader.backend(),
              site_id: site_id
            }, domain: domain)

            {:ok, url}

          {:error, reason} ->
            {:postpone, reason}
        end
      end)

    {:noreply,
     socket
     |> put_flash(:info, "Uploaded #{length(uploaded_entries)} file(s)")
     |> assign(:media, load_media(site_id))}
  end

  def handle_event("delete_media", %{"id" => id}, socket) do
    media = Ash.get!(AshCms.media_resource(), id, domain: AshCms.domain())

    # Delete from storage
    AshCms.Media.Uploader.delete(media.storage_path)

    # Delete record
    Ash.destroy!(media, domain: AshCms.domain())

    {:noreply, assign(socket, :media, load_media(socket.assigns.site_id))}
  end

  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, socket |> assign(:filter, filter) |> assign(:media, load_media(socket.assigns.site_id, filter, socket.assigns.search))}
  end

  def handle_event("search", %{"value" => search}, socket) do
    {:noreply, socket |> assign(:search, search) |> assign(:media, load_media(socket.assigns.site_id, socket.assigns.filter, search))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 24px; max-width: 1200px; margin: 0 auto;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <h1>Media Library — <%= @site && @site.name %></h1>
        <label style="padding: 8px 18px; background: var(--ash-cms-primary); color: var(--ash-cms-on-accent); border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 0.875rem;">
          <.live_file_input upload={@uploads.files} style="display: none;" />
          Upload Files
        </label>
      </div>

      <form phx-change="validate_upload" phx-submit="upload" style="margin-bottom: 24px;">
        <%= for entry <- @uploads.files.entries do %>
          <div style="display: flex; align-items: center; gap: 12px; padding: 8px; border: 1px solid var(--ash-cms-border); border-radius: 6px; margin-bottom: 8px;">
            <span><%= entry.client_name %></span>
            <progress value={entry.progress} max="100" style="flex: 1;"><%= entry.progress %>%</progress>
            <%= if entry.done? do %>
              <span style="color: green;">✓</span>
            <% end %>
          </div>
        <% end %>

        <%= if Enum.any?(@uploads.files.entries) do %>
          <button type="submit" style="padding: 8px 16px; background: var(--ash-cms-success); color: var(--ash-cms-on-accent); border: none; border-radius: 6px; cursor: pointer;">
            Upload All
          </button>
        <% end %>
      </form>

      <div style="display: flex; gap: 12px; margin-bottom: 20px; align-items: center;">
        <%= for {label, value} <- [{"All", "all"}, {"Images", "images"}, {"Videos", "videos"}] do %>
          <button
            phx-click="set_filter"
            phx-value-filter={value}
            style={"padding: 6px 14px; border-radius: 6px; border: 1px solid var(--ash-cms-border); cursor: pointer; font-size: 0.875rem; background: #{if @filter == value, do: "#6366f1", else: "white"}; color: #{if @filter == value, do: "white", else: "#0f172a"};"}
          ><%= label %></button>
        <% end %>

        <input
          type="search"
          placeholder="Search media…"
          value={@search}
          phx-change="search"
          phx-debounce="300"
          style="margin-left: auto; padding: 6px 12px; border: 1px solid var(--ash-cms-border); border-radius: 6px; font-size: 0.875rem;"
        />
      </div>

      <%= if Enum.empty?(@media) do %>
        <div style="text-align: center; padding: 64px; color: var(--ash-cms-text-muted);">
          <p>No media yet. Upload some files to get started.</p>
        </div>
      <% else %>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px;">
          <%= for item <- @media do %>
            <div style="border: 1px solid var(--ash-cms-border); border-radius: 8px; overflow: hidden; background: var(--ash-cms-bg);">
              <%= if String.starts_with?(item.content_type || "", "image/") do %>
                <img src={item.url} style="width: 100%; height: 110px; object-fit: cover; display: block;" alt={item.alt_text || item.name} />
              <% else %>
                <div style="width: 100%; height: 110px; background: var(--ash-cms-surface); display: flex; align-items: center; justify-content: center; font-size: 2rem;">
                  <%= media_emoji(item.content_type) %>
                </div>
              <% end %>
              <div style="padding: 8px;">
                <p style="margin: 0 0 4px; font-size: 0.75rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"><%= item.name %></p>
                <p style="margin: 0 0 8px; font-size: 0.7rem; color: var(--ash-cms-text-muted);"><%= format_size(item.size) %></p>
                <div style="display: flex; gap: 4px;">
                  <a href={item.url} target="_blank" style="font-size: 0.7rem; color: var(--ash-cms-primary);">View</a>
                  <button phx-click="delete_media" phx-value-id={item.id}
                          style="font-size: 0.7rem; color: var(--ash-cms-danger); border: none; background: none; cursor: pointer; margin-left: auto;"
                          data-confirm={"Delete #{item.name}?"}>Delete</button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_media(site_id, filter \\ "all", search \\ "") do
    action = if filter == "images", do: :images, else: :for_site

    AshCms.media_resource()
    |> Ash.Query.for_read(action, %{site_id: site_id})
    |> Ash.read!(domain: AshCms.domain())
    |> Enum.filter(fn m ->
      search == "" or String.contains?(String.downcase(m.name || ""), String.downcase(search))
    end)
  rescue
    _ -> []
  end

  defp media_emoji(ct) do
    cond do
      String.starts_with?(ct || "", "video/") -> "🎬"
      String.starts_with?(ct || "", "audio/") -> "🎵"
      ct == "application/pdf" -> "📄"
      true -> "📁"
    end
  end

  defp format_size(nil), do: "—"
  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
