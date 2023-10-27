import Config

config :logger, level: :warning

# config :testcontainers,
#   log_level: :warning

test_db_opts = [
  username: "test",
  password: "test",
  hostname: "localhost",
  database: "testcontainers_test",
  queue_target: 30_000,
  queue_interval: 30_000
]

config :testcontainers,
       Testcontainers.MysqlRepo,
       Keyword.merge(test_db_opts, port: 3336)

config :testcontainers,
       Testcontainers.PostgresRepo,
       Keyword.merge(test_db_opts, port: 5442)
