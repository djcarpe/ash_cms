defmodule AshCms.Live.SiteLive do
  @moduledoc "Create/edit a CMS site."

  use Phoenix.LiveView

  @impl true
  def mount(params, _session, socket) do
    site_id = params["site_id"]
    domain = AshCms.domain()

    {site, action} =
      if site_id do
        {Ash.get!(AshCms.site_resource(), site_id, domain: domain), :edit}
      else
        {%{name: "", slug: "", domain: "", description: "", css_url: "", js_url: ""}, :new}
      end

    {:ok,
     socket
     |> assign(:site, site)
     |> assign(:action, action)
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_event("save", %{"site" => attrs}, socket) do
    domain = AshCms.domain()
    site_mod = AshCms.site_resource()

    result =
      case socket.assigns.action do
        :new -> Ash.create(site_mod, attrs, domain: domain)
        :edit -> Ash.update(socket.assigns.site, attrs, domain: domain)
      end

    case result do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, "Site saved!")
         |> push_navigate(to: "/cms/sites/#{site.id}/pages")}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        errs = Map.new(errors, &{&1.field, &1.message})
        {:noreply, assign(socket, :errors, errs)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="max-width: 600px; margin: 32px auto; padding: 0 24px;">
      <h1><%= if @action == :new, do: "New Site", else: "Edit Site" %></h1>

      <form phx-submit="save" style="display: flex; flex-direction: column; gap: 16px;">
        <div>
          <label>Site Name *</label>
          <input type="text" name="site[name]" value={@site[:name] || ""} required
                 style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;" />
          <%= if @errors[:name], do: ~H"<p style='color: red; font-size: 0.875rem;'>{@errors[:name]}</p>" %>
        </div>

        <div>
          <label>Slug * (URL-safe identifier)</label>
          <input type="text" name="site[slug]" value={@site[:slug] || ""} placeholder="my-site"
                 style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;" />
        </div>

        <div>
          <label>Domain (optional, e.g. mysite.com)</label>
          <input type="text" name="site[domain]" value={@site[:domain] || ""}
                 style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;" />
        </div>

        <div>
          <label>Description</label>
          <textarea name="site[description]" rows="3"
                    style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;"><%= @site[:description] || "" %></textarea>
        </div>

        <div>
          <label>CSS URL (optional)</label>
          <input type="text" name="site[css_url]" value={@site[:css_url] || ""} placeholder="/assets/site.css"
                 style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;" />
        </div>

        <div>
          <label>JS URL (optional)</label>
          <input type="text" name="site[js_url]" value={@site[:js_url] || ""} placeholder="/assets/site.js"
                 style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px;" />
        </div>

        <div>
          <label>Custom CSS (optional, injected on every page)</label>
          <textarea name="site[custom_css]" rows="5"
                    style="display: block; width: 100%; padding: 8px; border: 1px solid #e2e8f0; border-radius: 6px; font-family: monospace;"><%= @site[:custom_css] || "" %></textarea>
        </div>

        <div style="display: flex; gap: 12px;">
          <button type="submit" class="ash-cms-btn-primary ash-cms-btn">Save Site</button>
          <a href="/cms" class="ash-cms-btn ash-cms-btn-ghost">Cancel</a>
        </div>
      </form>
    </div>
    """
  end
end
