import Config

config :kafka_ex, disable_default_worker: true

import_config "#{Mix.env()}.exs"
