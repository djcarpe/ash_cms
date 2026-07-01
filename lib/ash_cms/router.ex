defmodule AshCms.Router do
  @moduledoc """
  Phoenix router macro that adds AshCms routes to your router.

  ## Usage

  Import the macro in your Phoenix router and call `ash_cms_routes/1`
  at the **end** of your router module so the CMS catch-all doesn't shadow
  your own routes:

      defmodule MyAppWeb.Router do
        use Phoenix.Router
        import AshCms.Router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_live_flash
          plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end

        scope "/", MyAppWeb do
          pipe_through :browser
          get "/", PageController, :index
        end

        # CMS admin panel routes
        ash_cms_admin_routes("/cms")

        # CMS public page catch-all — must be last
        scope "/", MyAppWeb do
          pipe_through :browser
          ash_cms_routes()
        end
      end

  ## Options

  - `:pipe_through` — list of plugs (default: `[:browser]`)
  - `:scope` — URL prefix (default: `"/"`)
  """

  defmacro __using__(_opts) do
    quote do
      import AshCms.Router
    end
  end

  @doc """
  Adds the public CMS page catch-all route.
  Must be placed INSIDE an existing `scope` block, at the end.
  """
  defmacro ash_cms_routes(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      live "/*ash_cms_path", AshCms.Live.PageLive, :show
    end
  end

  @doc """
  Adds the CMS admin panel routes under the given prefix (default `/cms`).

  The admin panel provides:
  - `/cms` — dashboard with all sites and pages
  - `/cms/sites` — site management
  - `/cms/sites/:site_id/pages` — page list for a site
  - `/cms/sites/:site_id/pages/new` — create a new page
  - `/cms/sites/:site_id/pages/:page_id/edit` — visual/code editor
  - `/cms/sites/:site_id/components` — component manager
  - `/cms/sites/:site_id/media` — media library
  - `/cms/sites/:site_id/layouts` — layout manager
  """
  defmacro ash_cms_admin_routes(prefix \\ "/cms", opts \\ []) do
    quote bind_quoted: [prefix: prefix, opts: opts] do
      scope prefix do
        pipe_through(opts[:pipe_through] || [:browser])

        live "/", AshCms.Live.DashboardLive, :index
        live "/sites", AshCms.Live.SiteListLive, :index
        live "/sites/new", AshCms.Live.SiteLive, :new
        live "/sites/:site_id", AshCms.Live.SiteLive, :show
        live "/sites/:site_id/edit", AshCms.Live.SiteLive, :edit

        live "/sites/:site_id/pages", AshCms.Live.PageListLive, :index
        live "/sites/:site_id/pages/new", AshCms.Live.EditorLive, :new
        live "/sites/:site_id/pages/:page_id/edit", AshCms.Live.EditorLive, :edit
        live "/sites/:site_id/pages/:page_id/preview", AshCms.Live.PageLive, :preview

        live "/sites/:site_id/components", AshCms.Live.ComponentListLive, :index
        live "/sites/:site_id/components/new", AshCms.Live.ComponentLive, :new
        live "/sites/:site_id/components/:component_id/edit", AshCms.Live.ComponentLive, :edit

        live "/sites/:site_id/layouts", AshCms.Live.LayoutListLive, :index
        live "/sites/:site_id/layouts/new", AshCms.Live.LayoutLive, :new
        live "/sites/:site_id/layouts/:layout_id/edit", AshCms.Live.LayoutLive, :edit

        live "/sites/:site_id/media", AshCms.Live.MediaLibraryLive, :index
      end
    end
  end
end
