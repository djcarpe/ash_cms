import Config

config :example, ecto_repos: [Example.Repo]

config :example, ash_domains: [Example.CMS]

config :example, Example.Repo,
  database: Path.expand("../priv/repo/example_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5

config :example, ExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExampleWeb.ErrorHTML, json: ExampleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Example.PubSub,
  live_view: [signing_salt: "ash_cms_example_salt"]

config :example, :generators, timestamp_type: :utc_datetime

# AshCms configuration
config :ash_cms,
  domain: Example.CMS,
  site_resource: Example.CMS.Site,
  page_resource: Example.CMS.Page,
  component_resource: Example.CMS.Component,
  layout_resource: Example.CMS.Layout,
  media_resource: Example.CMS.Media,
  endpoint: ExampleWeb.Endpoint,
  pubsub_server: Example.PubSub,
  media_storage: :local,
  upload_dir: "priv/static/uploads"

# Esbuild
config :esbuild,
  version: "0.21.5",
  example: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets
             --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Sass
config :dart_sass,
  version: "1.70.0",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
