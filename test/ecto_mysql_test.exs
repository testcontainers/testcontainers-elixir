defmodule Testcontainers.EctoMysqlTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  test "can use ecto function" do
    {:ok, container} =
      mysql_container(
        app: :testcontainers,
        migrations_path: "../../../../test/fixtures/test_mysql_migrations",
        repo: Testcontainers.MysqlRepo,
        port: 3336
      )

    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.TestUser) == []
    Testcontainers.stop_container(container.container_id)
  end
end
