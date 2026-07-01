defmodule ExampleWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router
  import AshCms.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # CMS admin panel (no auth for the demo — add auth in production!)
  ash_cms_admin_routes("/cms")

  # Public routes
  scope "/", ExampleWeb do
    pipe_through :browser

    # You can add your own app routes here before the CMS catch-all
    get "/health", HealthController, :index
  end

  # Phoenix LiveDashboard (dev only)
  if Application.compile_env(:example, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: ExampleWeb.Telemetry
    end
  end

  # CMS page catch-all — must be LAST (no alias so AshCms modules are not scoped)
  scope "/" do
    pipe_through :browser
    ash_cms_routes()
  end
end
