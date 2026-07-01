defmodule Example.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # SQLite Repo
      Example.Repo,
      # Telemetry
      ExampleWeb.Telemetry,
      # PubSub
      {Phoenix.PubSub, name: Example.PubSub},
      # Phoenix Endpoint
      ExampleWeb.Endpoint,
      # AshCms supervisor — starts page servers for all published pages
      AshCms.CMSSupervisor
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
