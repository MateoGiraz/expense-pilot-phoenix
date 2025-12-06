# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :expense_pilot,
  ecto_repos: [ExpensePilot.Repo],
  generators: [timestamp_type: :utc_datetime],
  expenses_service_url: System.get_env("EXPENSES_SERVICE_URL")

# Configures the endpoint
config :expense_pilot, ExpensePilotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExpensePilotWeb.ErrorHTML, json: ExpensePilotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ExpensePilot.PubSub,
  live_view: [signing_salt: "QE+gov0j"]


# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  expense_pilot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  expense_pilot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger - simplified configuration
config :logger,
  backends: [:console]

config :logger, :console,
  format: "[$level] $message\n",
  level: :info

config :new_relic_agent,
  app_name: "expense-pilot",
  license_key: "8bb38f46c7cf49c8e68b30256a021068FFFFNRAL",
  httpc_request_options: [connect_timeout: 5000],
  logs_in_context: :direct


config :logflare_logger_backend,
  url: System.get_env("LOGFLARE_URL"),
  api_key: System.get_env("LOGFLARE_API_KEY", "ffcd38d074b9b21302abf6caedfb4ac8fb8036d090542fe0851e9b04d06fabcc"),
  source_id: System.get_env("LOGFLARE_SOURCE_ID", "d1e53b3d-1c9b-41d7-b3c6-86c15b06a59c"),
  level: :info,
  flush_interval: 1_000,
  max_batch_size: 50,
  metadata: :all

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Guardian for JWT authentication
config :expense_pilot, ExpensePilot.Accounts.Guardian,
  issuer: "expense_pilot",
  secret_key: "f/jwBNYA85YpgGh/YnZhGMPRoKZ1QkMkqEmHJJVtymj8KgIsJ1H7yyJD6unIaQmk" # This is just for development, use a proper secret in production

# AWS Configuration
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: [{:system, "AWS_REGION"}, "us-east-1"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
