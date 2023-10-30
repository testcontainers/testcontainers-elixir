defmodule Testcontainers.EctoPostgresTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  test "can use ecto function" do
    {:ok, _container} =
      postgres_container(
        app: :testcontainers,
        migrations_path: "#{__DIR__}/support/migrations",
        repo: Testcontainers.PostgresRepo,
        port: 5442
      )

    {:ok, _pid} = Testcontainers.PostgresRepo.start_link()
    assert Testcontainers.PostgresRepo.all(Testcontainers.TestUser) == []
  end
end
