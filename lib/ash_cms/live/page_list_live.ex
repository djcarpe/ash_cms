defmodule AshCms.Live.PageListLive do
  @moduledoc "Lists all pages for a site with quick actions (edit, publish, delete)."

  use Phoenix.LiveView

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    site = Ash.get!(AshCms.site_resource(), site_id, domain: AshCms.domain())
    pages = load_pages(site_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AshCms.pubsub_server(), AshCms.site_topic(site_id))
    end

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:site_id, site_id)
     |> assign(:pages, pages)
     |> assign(:page_title, "Pages — #{site.name}")}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("delete_page", %{"id" => id}, socket) do
    page = Ash.get!(AshCms.page_resource(), id, domain: AshCms.domain())
    Ash.destroy!(page, domain: AshCms.domain())
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  def handle_event("publish_page", %{"id" => id}, socket) do
    page = Ash.get!(AshCms.page_resource(), id, domain: AshCms.domain())
    {:ok, _} = Ash.update(page, %{}, action: :publish, domain: AshCms.domain())
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  def handle_event("unpublish_page", %{"id" => id}, socket) do
    page = Ash.get!(AshCms.page_resource(), id, domain: AshCms.domain())
    {:ok, _} = Ash.update(page, %{}, action: :unpublish, domain: AshCms.domain())
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  @impl true
  def handle_info({:page_updated, _}, socket) do
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  def handle_info({:page_published, _}, socket) do
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  def handle_info({:page_unpublished, _}, socket) do
    {:noreply, assign(socket, :pages, load_pages(socket.assigns.site_id))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ash-cms-page-list">
      <div class="ash-cms-page-list-header">
        <div>
          <a href="/cms" class="ash-cms-breadcrumb-link">Dashboard</a>
          <span>›</span>
          <span><%= @site.name %></span>
        </div>
        <a href={"/cms/sites/#{@site_id}/pages/new"} class="ash-cms-btn-primary">
          + New Page
        </a>
      </div>

      <%= if Enum.empty?(@pages) do %>
        <div class="ash-cms-page-list-empty">
          <p>No pages yet. Create your first page!</p>
          <a href={"/cms/sites/#{@site_id}/pages/new"} class="ash-cms-btn-primary">
            Create Page
          </a>
        </div>
      <% else %>
        <table class="ash-cms-table">
          <thead>
            <tr>
              <th>Title</th>
              <th>Slug</th>
              <th>Status</th>
              <th>Last Updated</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for page <- @pages do %>
              <tr class="ash-cms-table-row">
                <td class="ash-cms-page-title-cell">
                  <a href={"/cms/sites/#{@site_id}/pages/#{page.id}/edit"}>
                    <%= page.title %>
                  </a>
                </td>
                <td class="ash-cms-page-slug-cell">/<%= page.slug %></td>
                <td>
                  <%= if page.published do %>
                    <span class="ash-cms-badge ash-cms-badge-green">Published</span>
                  <% else %>
                    <span class="ash-cms-badge ash-cms-badge-gray">Draft</span>
                  <% end %>
                </td>
                <td><%= format_date(page.updated_at) %></td>
                <td class="ash-cms-page-actions">
                  <a href={"/cms/sites/#{@site_id}/pages/#{page.id}/edit"}
                     class="ash-cms-btn-xs">Edit</a>
                  <%= if page.published do %>
                    <button phx-click="unpublish_page" phx-value-id={page.id}
                            class="ash-cms-btn-xs ash-cms-btn-warning">Unpublish</button>
                  <% else %>
                    <button phx-click="publish_page" phx-value-id={page.id}
                            class="ash-cms-btn-xs ash-cms-btn-primary">Publish</button>
                  <% end %>
                  <button phx-click="delete_page" phx-value-id={page.id}
                          class="ash-cms-btn-xs ash-cms-btn-danger"
                          data-confirm={"Delete '#{page.title}'?"}>Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  defp load_pages(site_id) do
    AshCms.page_resource()
    |> Ash.Query.for_read(:by_site, %{site_id: site_id})
    |> Ash.Query.sort(sort_order: :asc, inserted_at: :asc)
    |> Ash.read!(domain: AshCms.domain())
  rescue
    _ -> []
  end

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%b %d, %Y")
end
