defmodule AshCms.Live.DashboardLive do
  @moduledoc "CMS admin dashboard — lists all sites and their page counts."

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    sites = load_sites()

    {:ok,
     socket
     |> assign(:sites, sites)
     |> assign(:page_title, "CMS Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ash-cms-dashboard">
      <div class="ash-cms-dashboard-header">
        <h1>CMS Dashboard</h1>
        <a href="/cms/sites/new" class="ash-cms-btn-primary">+ New Site</a>
      </div>

      <%= if Enum.empty?(@sites) do %>
        <div class="ash-cms-dashboard-empty">
          <h2>No sites yet</h2>
          <p>Create your first site to start building pages.</p>
          <a href="/cms/sites/new" class="ash-cms-btn-primary">Create Site</a>
        </div>
      <% else %>
        <div class="ash-cms-sites-grid">
          <%= for site <- @sites do %>
            <div class="ash-cms-site-card">
              <div class="ash-cms-site-card-header">
                <h3 class="ash-cms-site-name"><%= site.name %></h3>
                <span class="ash-cms-site-domain"><%= site.domain || site.slug %></span>
              </div>
              <div class="ash-cms-site-card-body">
                <div class="ash-cms-site-stats">
                  <span>Pages: <strong><%= length(site.pages || []) %></strong></span>
                </div>
                <div class="ash-cms-site-card-actions">
                  <a href={"/cms/sites/#{site.id}/pages"} class="ash-cms-btn-secondary">
                    Pages
                  </a>
                  <a href={"/cms/sites/#{site.id}/media"} class="ash-cms-btn-ghost">
                    Media
                  </a>
                  <a href={"/cms/sites/#{site.id}/edit"} class="ash-cms-btn-ghost">
                    Settings
                  </a>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_sites do
    AshCms.site_resource()
    |> Ash.read!(domain: AshCms.domain(), load: [:pages])
  rescue
    _ -> []
  end
end
