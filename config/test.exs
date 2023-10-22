import Config

config :logger, level: :warning

# config :testcontainers,
#   log_level: :warning

config :testcontainers, Testcontainers.MysqlRepo,
  username: "test",
  password: "test",
  hostname: "localhost",
  database: "testcontainers_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :testcontainers, Testcontainers.PostgresRepo,
  username: "test",
  password: "test",
  hostname: "localhost",
  database: "testcontainers_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
