defmodule AshCms.Live.ComponentLive do
  @moduledoc "Create/edit a user-defined CMS component with live template preview."

  use Phoenix.LiveView

  import Phoenix.HTML, only: [raw: 1]

  @impl true
  def mount(params, _session, socket) do
    site_id = params["site_id"]
    component_id = params["component_id"]
    domain = AshCms.domain()

    {component, action} =
      if component_id do
        comp = Ash.get!(AshCms.component_resource(), component_id, domain: domain)
        {comp, :edit}
      else
        {%{name: "", slug: "", description: "", template: default_template(), props_schema: %{}}, :new}
      end

    site = Ash.get!(AshCms.site_resource(), site_id, domain: domain)

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:site_id, site_id)
     |> assign(:component, component)
     |> assign(:action, action)
     |> assign(:preview_html, "")
     |> assign(:template_input, component[:template] || default_template())}
  end

  @impl true
  def handle_event("preview_template", %{"template" => template}, socket) do
    preview =
      EEx.eval_string(template, assigns: %{
        props: (socket.assigns.component[:default_props] || %{}),
        site: socket.assigns.site
      })

    {:noreply, socket |> assign(:preview_html, preview) |> assign(:template_input, template)}
  rescue
    e -> {:noreply, assign(socket, :preview_html, "Template error: #{inspect(e)}")}
  end

  def handle_event("code_changed", %{"content" => content}, socket) do
    handle_event("preview_template", %{"template" => content}, socket)
  end

  def handle_event("save", %{"component" => attrs}, socket) do
    domain = AshCms.domain()
    comp_mod = AshCms.component_resource()

    merged_attrs = Map.merge(attrs, %{
      "site_id" => socket.assigns.site_id,
      "template" => socket.assigns.template_input
    })

    result =
      case socket.assigns.action do
        :new -> Ash.create(comp_mod, merged_attrs, domain: domain)
        :edit -> Ash.update(socket.assigns.component, merged_attrs, domain: domain)
      end

    case result do
      {:ok, comp} ->
        {:noreply,
         socket
         |> put_flash(:info, "Component saved!")
         |> push_navigate(to: "/cms/sites/#{socket.assigns.site_id}/components")}

      {:error, err} ->
        {:noreply, put_flash(socket, :error, "Save failed: #{inspect(err)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display: flex; flex-direction: column; height: 100vh; overflow: hidden;">
      <div style="padding: 16px 24px; border-bottom: 1px solid #e2e8f0; display: flex; gap: 12px; align-items: center;">
        <a href={"/cms/sites/#{@site_id}/components"}>← Components</a>
        <h1 style="margin: 0; font-size: 1.125rem; font-weight: 700;">
          <%= if @action == :new, do: "New Component", else: "Edit Component" %>
        </h1>
      </div>

      <div style="display: flex; flex: 1; overflow: hidden;">
        <%!-- Left: metadata form --%>
        <form phx-submit="save" style="width: 280px; padding: 20px; border-right: 1px solid #e2e8f0; overflow-y: auto; display: flex; flex-direction: column; gap: 14px; flex-shrink: 0;">
          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Name</label>
            <input type="text" name="component[name]" value={@component[:name] || ""} required
                   style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;" />
          </div>

          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Slug</label>
            <input type="text" name="component[slug]" value={@component[:slug] || ""} placeholder="my_component"
                   style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;" />
          </div>

          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Category</label>
            <select name="component[category]"
                    style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;">
              <option value="content">Content</option>
              <option value="layout">Layout</option>
              <option value="media">Media</option>
              <option value="interactive">Interactive</option>
              <option value="custom">Custom</option>
            </select>
          </div>

          <div>
            <label style="font-size: 0.75rem; font-weight: 500; color: #64748b; display: block; margin-bottom: 4px;">Description</label>
            <textarea name="component[description]" rows="2"
                      style="width: 100%; padding: 7px; border: 1px solid #e2e8f0; border-radius: 6px; box-sizing: border-box;"><%= @component[:description] || "" %></textarea>
          </div>

          <button type="submit" style="padding: 9px 16px; background: #6366f1; color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600;">
            Save Component
          </button>
        </form>

        <%!-- Center: template editor --%>
        <div style="flex: 1; display: flex; flex-direction: column; overflow: hidden;">
          <div style="padding: 8px 16px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; font-size: 0.8125rem; color: #64748b; font-weight: 500;">
            HEEx Template — use @props.field_name for component properties
          </div>
          <div
            id="component-monaco"
            style="flex: 1;"
            phx-hook="AshCMSMonaco"
            data-content={@template_input}
            data-language="html"
            phx-update="ignore"
          ></div>
        </div>

        <%!-- Right: preview --%>
        <div style="width: 360px; border-left: 1px solid #e2e8f0; display: flex; flex-direction: column; flex-shrink: 0;">
          <div style="padding: 8px 16px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; font-size: 0.8125rem; color: #64748b; font-weight: 500;">
            Preview (with default props)
          </div>
          <div style="flex: 1; overflow-y: auto; padding: 16px;">
            <%= raw(@preview_html) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp default_template do
    ~s"""
    <div class="my-component" style="padding: 16px; border: 1px solid #e2e8f0; border-radius: 8px;">
      <h3><%= @props["title"] %></h3>
      <p><%= @props["content"] %></p>
    </div>
    """
  end
end
