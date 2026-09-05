defmodule AshCms.Live.PageLive do
  @moduledoc """
  LiveView that serves public CMS pages and handles the full LiveView lifecycle.

  ## Route resolution

  1. Extract the path from `ash_cms_path` param (e.g. `["about"]` or `["blog", "my-post"]`)
  2. Determine site from hostname (domain-based) or the first path segment (slug-based)
  3. Look up the page server via `AshCms.Registry`
  4. If found, render the page and apply site CSS/JS
  5. Subscribe to PubSub for live updates — if the CMS editor publishes a change,
     this LiveView automatically re-renders without a page reload

  ## Preview mode

  When `action: :preview`, the page loads directly from the database and shows
  a preview banner, skipping the Group registry lookup.
  """

  use Phoenix.LiveView

  import Phoenix.HTML, only: [raw: 1]

  require Logger

  @impl true
  def mount(params, session, socket) do
    path_parts = params["ash_cms_path"] || []
    host = get_connect_info(socket, :peer_data) |> get_host() ||
             Map.get(params, "host", "localhost")

    socket =
      socket
      |> assign(:path_parts, path_parts)
      |> assign(:host, host)
      |> assign(:page, nil)
      |> assign(:site, nil)
      |> assign(:rendered_html, nil)
      |> assign(:error, nil)
      |> assign(:loading, true)
      |> assign(:preview_mode, socket.assigns.live_action == :preview)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    path_parts = params["ash_cms_path"] || []
    page_id = params["page_id"]
    site_id = params["site_id"]

    # The host comes from the request URI, which is always present here and
    # always correct. It used to come from `get_connect_info(:peer_data)` via
    # `get_host/1`, whose every clause returned nil - so the host silently fell
    # back to "localhost" and `lookup_by_domain/2` could never match a site,
    # making domain-based routing dead code.
    socket = assign(socket, :host, host_from_uri(uri) || socket.assigns.host)

    socket =
      if socket.assigns.live_action == :preview && page_id do
        load_preview(socket, site_id, page_id)
      else
        load_page_from_registry(socket, path_parts)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:page_updated, page}, socket) do
    if socket.assigns.page && socket.assigns.page.id == page.id do
      {:noreply, render_page(socket, page, socket.assigns.site)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:page_published, page}, socket) do
    handle_info({:page_updated, page}, socket)
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @error do %>
      <div class="ash-cms-error">
        <h1>Page Not Found</h1>
        <p>The page you're looking for doesn't exist or has been unpublished.</p>
      </div>
    <% else %>
      <%= if @loading do %>
        <div class="ash-cms-loading">Loading...</div>
      <% else %>
        <%= if @preview_mode do %>
          <div class="ash-cms-preview-banner">
            <span>Preview Mode</span>
            <%= if @page do %>
              <a href={"/cms/sites/#{@page.site_id}/pages/#{@page.id}/edit"}>Back to Editor</a>
            <% end %>
          </div>
        <% end %>

        <%= if @site && (@site.css_url || @site.custom_css) do %>
          <style>
            <%= raw(@site.custom_css || "") %>
          </style>
          <%= if @site.css_url do %>
            <link rel="stylesheet" href={@site.css_url} />
          <% end %>
        <% end %>

        <%= if @page && @page.custom_css do %>
          <style><%= raw(@page.custom_css) %></style>
        <% end %>

        <div class="ash-cms-page" data-page-id={@page && @page.id}>
          <%= raw(@rendered_html || "") %>
        </div>

        <%= if @site && @site.js_url do %>
          <script src={@site.js_url}></script>
        <% end %>

        <%= if @page && @page.custom_js do %>
          <script><%= raw(@page.custom_js) %></script>
        <% end %>
      <% end %>
    <% end %>
    """
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp load_page_from_registry(socket, path_parts) do
    slug = Enum.join(path_parts, "/")
    host = socket.assigns.host

    result =
      case AshCms.Registry.lookup_by_domain(host, slug) do
        {pid, meta} ->
          {:found, pid, meta}

        nil ->
          # Try first-segment as site slug
          {site_slug, page_slug} = split_site_page(path_parts)

          case AshCms.Registry.lookup_by_slug(site_slug, page_slug) do
            {pid, meta} -> {:found, pid, meta}
            nil -> {:not_found}
          end
      end

    case result do
      {:found, pid, _meta} ->
        page = AshCms.PageServer.get_page(pid)
        site = AshCms.PageServer.get_site(pid)

        # Subscribe to live updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(AshCms.pubsub_server(), AshCms.page_topic(page.id))
        end

        socket
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> render_page(page, site)

      {:not_found} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, :not_found)
        |> assign(:page, nil)
        |> assign(:site, nil)
        |> assign(:rendered_html, nil)
    end
  end

  defp load_preview(socket, site_id, page_id) do
    page_mod = AshCms.page_resource()
    domain = AshCms.domain()

    case Ash.get(page_mod, page_id, domain: domain, load: [:site, :layout]) do
      {:ok, page} when not is_nil(page) and page.site_id == site_id ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(AshCms.pubsub_server(), AshCms.page_topic(page.id))
        end

        socket
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> render_page(page, page.site)

      _ ->
        assign(socket, loading: false, error: :not_found)
    end
  end

  defp render_page(socket, page, site) do
    components =
      AshCms.component_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: page.site_id})
      |> Ash.read!(domain: AshCms.domain())

    html =
      case AshCms.Renderer.render_page(page, site: site, components: components) do
        {:ok, html} -> html
        {:error, _} -> "<p>Error rendering page content.</p>"
      end

    socket
    |> assign(:page, page)
    |> assign(:site, site)
    |> assign(:rendered_html, html)
  end

  defp split_site_page([site_slug | rest]) when rest != [], do: {site_slug, Enum.join(rest, "/")}
  defp split_site_page([slug]), do: {"default", slug}
  defp split_site_page([]), do: {"default", "home"}

  defp host_from_uri(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  defp host_from_uri(_), do: nil

  # `mount/3` runs before `handle_params/3` and has no URI, so it seeds a
  # placeholder that `handle_params/3` then replaces with the real host.
  defp get_host(_), do: nil
end
