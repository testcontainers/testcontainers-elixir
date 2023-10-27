import Config

config :logger, level: :warning

# config :testcontainers,
#   log_level: :warning

config :testcontainers, Testcontainers.MysqlRepo,
  username: "test",
  password: "test",
  hostname: "localhost",
  database: "testcontainers_test",
  port: 3336,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2,
  queue_target: 30_000,
  queue_interval: 30_000

config :testcontainers, Testcontainers.PostgresRepo,
  username: "test",
  password: "test",
  hostname: "localhost",
  database: "testcontainers_test",
  port: 5442,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2,
  queue_target: 30_000,
  queue_interval: 30_000
