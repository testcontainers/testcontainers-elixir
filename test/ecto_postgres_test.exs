defmodule Testcontainers.PostgresRepo do
  use Ecto.Repo,
    otp_app: :testcontainers,
    adapter: Ecto.Adapters.Postgres
end

defmodule Testcontainers.PostgresUser do
  use Ecto.Schema

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:confirmed_at, :naive_datetime)

    timestamps()
  end
end

defmodule Testcontainers.EctoPostgresTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  test "can use ecto function" do
    :ok =
      postgres_container(
        app: :testcontainers,
        migrations_path: "../../../../test/fixtures/test_postgres_migrations",
        repo: :"Elixir.Testcontainers.PostgresRepo"
      )

    {:ok, _pid} = Testcontainers.PostgresRepo.start_link()
    assert Testcontainers.PostgresRepo.all(Testcontainers.PostgresUser) == []
  end
end
