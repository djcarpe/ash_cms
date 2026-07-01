defmodule AshCms.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Group-based distributed page registry
      {Group, name: AshCms.Registry},
      # Dynamic supervisor for per-page GenServers
      {DynamicSupervisor, name: AshCms.PageSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: AshCms.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
