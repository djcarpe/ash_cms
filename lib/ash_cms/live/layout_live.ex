defmodule AshCms.Live.LayoutLive do
  @moduledoc "Create/edit a CMS layout template."
  use Phoenix.LiveView

  @impl true
  def mount(params, _session, socket) do
    site_id = params["site_id"]
    layout_id = params["layout_id"]
    domain = AshCms.domain()

    {layout, action} =
      if layout_id do
        {Ash.get!(AshCms.layout_resource(), layout_id, domain: domain), :edit}
      else
        {%{name: "", slug: "", template: default_template()}, :new}
      end

    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:site_id, site_id)
     |> assign(:layout, layout)
     |> assign(:action, action)
     |> assign(:template_input, Map.get(layout, :template) || default_template())}
  end

  @impl true
  def handle_event("code_changed", %{"content" => content}, socket) do
    {:noreply, assign(socket, :template_input, content)}
  end

  def handle_event("save", %{"layout" => attrs}, socket) do
    domain = AshCms.domain()
    layout_mod = AshCms.layout_resource()
    merged = Map.merge(attrs, %{"site_id" => socket.assigns.site_id, "template" => socket.assigns.template_input})

    result =
      case socket.assigns.action do
        :new -> Ash.create(layout_mod, merged, domain: domain)
        :edit -> Ash.update(socket.assigns.layout, merged, domain: domain)
      end

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Layout saved!")
         |> push_navigate(to: "/cms/sites/#{socket.assigns.site_id}/layouts")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Save failed: #{inspect(err)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100vh;">
      <div style="padding: 12px 24px; border-bottom: 1px solid #e2e8f0; display: flex; align-items: center; gap: 16px; background: white;">
        <a href={"/cms/sites/#{@site_id}/layouts"}>← Layouts</a>
        <h1 style="margin: 0; font-size: 1.125rem;">
          <%= if @action == :new, do: "New Layout", else: "Edit Layout" %>
        </h1>
        <button phx-click="save" phx-value-layout={Jason.encode!(%{})}
                style="margin-left: auto; padding: 8px 18px; background: #6366f1; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600;"
                onclick="document.getElementById('layout-form-submit').click()">
          Save Layout
        </button>
      </div>

      <div style="display: flex; flex: 1; overflow: hidden;">
        <form id="layout-form" phx-submit="save" style="width: 240px; padding: 16px; border-right: 1px solid #e2e8f0; display: flex; flex-direction: column; gap: 12px; flex-shrink: 0;">
          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Name</label>
            <input type="text" name="layout[name]" value={Map.get(@layout, :name) || ""} required
                   style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;" />
          </div>
          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Slug</label>
            <input type="text" name="layout[slug]" value={Map.get(@layout, :slug) || ""}
                   style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;" />
          </div>
          <div>
            <label style="display: flex; align-items: center; gap: 8px; font-size: 0.875rem;">
              <input type="checkbox" name="layout[is_default]" value="true"
                     checked={Map.get(@layout, :is_default) == true} />
              Default layout for new pages
            </label>
          </div>
          <button type="submit" id="layout-form-submit" style="display: none;">Save</button>
        </form>

        <div
          id="layout-monaco"
          style="flex: 1;"
          phx-hook="AshCMSMonaco"
          data-content={@template_input}
          data-language="html"
          phx-update="ignore"
        ></div>
      </div>
    </div>
    """
  end

  defp default_template do
    """
    <header style="background: #1a1a2e; color: white; padding: 16px 32px;">
      <a href="/" style="color: white; font-weight: 700; text-decoration: none;">
        <%= @site.name %>
      </a>
    </header>

    <main>
      <%= @inner_content %>
    </main>

    <footer style="padding: 32px; text-align: center; color: #64748b; background: #f8fafc; border-top: 1px solid #e2e8f0;">
      © <%= Date.utc_today().year %> <%= @site.name %>
    </footer>
    """
  end
end
