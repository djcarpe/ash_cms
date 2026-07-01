import Config

config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "ash_cms_example_dev_secret_key_base_at_least_64_chars_long_xxxyyy",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:example, ~w(--sourcemap=inline --watch)]}
  ]

config :example, ExampleWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/example_web/(controllers|live|components)/.*(ex|heex)$",
      # Reload when AshCms templates change
      ~r"../../lib/ash_cms/live/.*(ex|heex)$",
      ~r"../../priv/static/ash_cms\.(js|css)$"
    ]
  ]

config :logger, level: :debug

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
config :phoenix_live_view, :debug_heex_annotations, true
