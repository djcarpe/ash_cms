defmodule AshCms.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your_org/ash_cms"

  def project do
    [
      app: :ash_cms,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      description: description(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AshCms.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ash, "~> 3.4"},
      {:spark, "~> 2.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:group, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:mime, "~> 2.0"},
      {:uuid, "~> 1.1"},
      # Optional: code installer
      {:igniter, "~> 0.5", optional: true},
      # Optional: S3 media storage
      {:ex_aws, "~> 2.5", optional: true},
      {:ex_aws_s3, "~> 2.5", optional: true},
      {:hackney, "~> 1.9", optional: true},
      # Dev
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:makeup_elixir, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs .formatter.exs README.md LICENSE)
    ]
  end

  defp description do
    "Full-featured CMS extension for Ash Framework with drag & drop and live code editing"
  end

  defp aliases do
    [setup: ["deps.get"]]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
