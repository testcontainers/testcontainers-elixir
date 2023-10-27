defmodule Testcontainers.PostgresRepo do
  use Ecto.Repo,
    otp_app: :testcontainers,
    adapter: Ecto.Adapters.Postgres
end
