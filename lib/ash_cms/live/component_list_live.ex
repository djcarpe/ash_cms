defmodule AshCms.Live.ComponentListLive do
  @moduledoc "Lists user-defined components for a site."
  use Phoenix.LiveView

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    domain = AshCms.domain()
    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)
    components =
      AshCms.component_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: site_id})
      |> Ash.read!(domain: domain)

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:site_id, site_id)
     |> assign(:components, components)}
  rescue
    _ -> {:ok, assign(socket, site_id: nil, site: nil, components: [])}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    comp = Ash.get!(AshCms.component_resource(), id, domain: AshCms.domain())
    Ash.destroy!(comp, domain: AshCms.domain())
    components =
      AshCms.component_resource()
      |> Ash.Query.for_read(:for_site, %{site_id: socket.assigns.site_id})
      |> Ash.read!(domain: AshCms.domain())
    {:noreply, assign(socket, :components, components)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 24px; max-width: 1000px; margin: 0 auto;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <div>
          <a href={"/cms/sites/#{@site_id}/pages"} style="color: #64748b; text-decoration: none; font-size: 0.875rem;">← Pages</a>
          <h1 style="margin: 4px 0 0;">Components — <%= @site && @site.name %></h1>
        </div>
        <a href={"/cms/sites/#{@site_id}/components/new"} class="ash-cms-btn ash-cms-btn-primary">
          + New Component
        </a>
      </div>

      <%= if Enum.empty?(@components) do %>
        <div style="text-align: center; padding: 48px; color: #64748b;">
          <p>No custom components yet.</p>
          <p>Create reusable blocks that you can drag into any page in this site.</p>
        </div>
      <% else %>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px;">
          <%= for comp <- @components do %>
            <div style="border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; background: white;">
              <div style="font-size: 1.5rem; margin-bottom: 8px;"><%= comp.icon || "🧩" %></div>
              <h3 style="margin: 0 0 4px; font-size: 0.9375rem; font-weight: 600;"><%= comp.name %></h3>
              <p style="margin: 0 0 12px; color: #64748b; font-size: 0.8125rem;"><%= comp.description %></p>
              <div style="display: flex; gap: 6px;">
                <a href={"/cms/sites/#{@site_id}/components/#{comp.id}/edit"} class="ash-cms-btn ash-cms-btn-xs">Edit</a>
                <button phx-click="delete" phx-value-id={comp.id}
                        class="ash-cms-btn ash-cms-btn-xs ash-cms-btn-danger"
                        data-confirm={"Delete #{comp.name}?"}>Delete</button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
