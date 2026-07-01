defmodule AshCms.Live.SiteListLive do
  @moduledoc "Lists all CMS sites."
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    sites = Ash.read!(AshCms.site_resource(), domain: AshCms.domain(), load: [:pages])
    {:ok, assign(socket, :sites, sites)}
  rescue
    _ -> {:ok, assign(socket, :sites, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="padding: 24px; max-width: 1000px; margin: 0 auto;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <h1>Sites</h1>
        <a href="/cms/sites/new" class="ash-cms-btn ash-cms-btn-primary">+ New Site</a>
      </div>

      <%= if Enum.empty?(@sites) do %>
        <p>No sites yet. <a href="/cms/sites/new">Create one</a>.</p>
      <% else %>
        <table class="ash-cms-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Slug</th>
              <th>Domain</th>
              <th>Pages</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for site <- @sites do %>
              <tr class="ash-cms-table-row">
                <td><strong><%= site.name %></strong></td>
                <td style="font-family: monospace; color: #64748b;"><%= site.slug %></td>
                <td><%= site.domain || "—" %></td>
                <td><%= length(site.pages || []) %></td>
                <td style="display: flex; gap: 4px;">
                  <a href={"/cms/sites/#{site.id}/pages"} class="ash-cms-btn ash-cms-btn-xs">Pages</a>
                  <a href={"/cms/sites/#{site.id}/edit"} class="ash-cms-btn ash-cms-btn-xs ash-cms-btn-ghost">Edit</a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end
end
