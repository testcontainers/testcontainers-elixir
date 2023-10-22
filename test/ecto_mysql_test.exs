defmodule Testcontainers.MysqlRepo do
  use Ecto.Repo,
    otp_app: :testcontainers,
    adapter: Ecto.Adapters.MyXQL
end

defmodule Testcontainers.MysqlUser do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    timestamps()
  end
end

defmodule Testcontainers.EctoMysqlTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  setup do
    :ok =
      mysql_container(
        app: :testcontainers,
        migrations_path: "../../../../test/fixtures/test_migrations",
        repo: :"Elixir.Testcontainers.MysqlRepo"
      )
  end

  test "can use ecto macro" do
    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.MysqlUser) == []
  end
end
