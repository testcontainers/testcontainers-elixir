defmodule Testcontainers.MysqlRepo do
  use Ecto.Repo,
    otp_app: :testcontainers,
    adapter: Ecto.Adapters.MyXQL
end
