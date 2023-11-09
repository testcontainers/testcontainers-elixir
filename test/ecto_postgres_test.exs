defmodule Testcontainers.EctoPostgresTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  require Testcontainers.PostgresRepo

  test "can use ecto function" do
    {:ok, container} =
      postgres_container(
        app: :testcontainers,
        migrations_path: "#{__DIR__}/support/migrations",
        repo: Testcontainers.PostgresRepo,
        persistent_volume_name: "testcontainers_ecto_postgres_test"
      )

    {:ok, _pid} = Testcontainers.PostgresRepo.start_link()
    assert Testcontainers.PostgresRepo.all(Testcontainers.TestUser) == []
    Testcontainers.stop_container(container.container_id)
  end
end
