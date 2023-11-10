import Config

config :logger, level: :warning

config :testcontainers, log_level: :warning

config :kafka_ex, disable_default_worker: true
