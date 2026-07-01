defmodule AshCms.Live.LayoutListLive do
  @moduledoc "Lists layouts for a site."
  use Phoenix.LiveView

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    domain = AshCms.domain()
    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)
    layouts =
      AshCms.layout_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: site_id})
      |> Ash.read!(domain: domain)
    {:ok, socket |> assign(:site, site) |> assign(:site_id, site_id) |> assign(:layouts, layouts)}
  rescue
    _ -> {:ok, assign(socket, site_id: nil, site: nil, layouts: [])}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    layout = Ash.get!(AshCms.layout_resource(), id, domain: AshCms.domain())
    Ash.destroy!(layout, domain: AshCms.domain())
    layouts =
      AshCms.layout_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: socket.assigns.site_id})
      |> Ash.read!(domain: AshCms.domain())
    {:noreply, assign(socket, :layouts, layouts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 24px; max-width: 900px; margin: 0 auto;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <h1>Layouts — <%= @site && @site.name %></h1>
        <a href={"/cms/sites/#{@site_id}/layouts/new"} class="ash-cms-btn ash-cms-btn-primary">+ New Layout</a>
      </div>

      <%= for layout <- @layouts do %>
        <div style="border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin-bottom: 12px; background: white; display: flex; justify-content: space-between; align-items: center;">
          <div>
            <h3 style="margin: 0 0 4px;"><%= layout.name %></h3>
            <code style="font-size: 0.8125rem; color: #64748b;"><%= layout.slug %></code>
            <%= if layout.is_default do %>
              <span class="ash-cms-badge ash-cms-badge-green" style="margin-left: 8px;">Default</span>
            <% end %>
          </div>
          <div style="display: flex; gap: 6px;">
            <a href={"/cms/sites/#{@site_id}/layouts/#{layout.id}/edit"} class="ash-cms-btn ash-cms-btn-xs">Edit</a>
            <button phx-click="delete" phx-value-id={layout.id}
                    class="ash-cms-btn ash-cms-btn-xs ash-cms-btn-danger"
                    data-confirm={"Delete #{layout.name}?"}>Delete</button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
