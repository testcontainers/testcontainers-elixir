defmodule Testcontainers.MysqlRepo do
  use Ecto.Repo,
    otp_app: :testcontainers,
    adapter: Ecto.Adapters.MyXQL
end

defmodule Testcontainers.MysqlUser do
  use Ecto.Schema

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)

    timestamps()
  end
end

defmodule Testcontainers.EctoMysqlTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  test "can use ecto function" do
    {:ok, container} =
      mysql_container(
        app: :testcontainers,
        migrations_path: "../../../../test/fixtures/test_mysql_migrations",
        repo: :"Elixir.Testcontainers.MysqlRepo",
        port: 33060
      )

    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.MysqlUser) == []
    Testcontainers.stop_container(container.container_id)
  end
end
