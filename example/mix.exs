defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Example.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:bandit, "~> 1.5"},
      # Ash
      {:ash, "~> 3.4"},
      {:ash_sqlite, "~> 0.2"},
      {:ash_phoenix, "~> 2.1"},
      # SQLite
      {:ecto_sqlite3, "~> 0.18"},
      # AshCms (this library, local path)
      {:ash_cms, path: ".."},
      # Utilities
      {:jason, "~> 1.4"},
      {:gettext, "~> 0.26"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:igniter, "~> 0.5", only: [:dev]},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup"],
      "assets.setup": ["esbuild.install --if-missing", "sass.install --if-missing"],
      "assets.build": ["esbuild default", "sass default"],
      "ash.migrate": ["ash_sqlite.generate_migrations", "ash_sqlite.migrate"],
      "ash.reset": ["ash_sqlite.drop", "ash.migrate", "run priv/repo/seeds.exs"]
    ]
  end
end
