import Config

# connect the app's asset module to Scenic
config :scenic, :assets, module: BreakingCues.Assets

config :breaking_cues, :output_viewport,
  name: :output_viewport,
  size: {1920, 1080},
  theme: :dark,
  default_scene: BreakingCues.Scene.DefaultOutput,
  drivers: [
    [
      module: Scenic.Driver.Offscreen,
      title: "Breaking Cues"
    ]
  ]

config :breaking_cues,
  ecto_repos: [BreakingCues.Repo]

# Configures the endpoint
config :breaking_cues, BreakingCuesWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: BreakingCuesWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: BreakingCues.PubSub,
  live_view: [signing_salt: "v3qImxJ7"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :breaking_cues, BreakingCues.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
