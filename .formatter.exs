[
  import_deps: [:ash, :spark, :phoenix, :phoenix_live_view],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/migrations/*.exs"]
]
