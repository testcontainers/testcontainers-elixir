defmodule Testcontainers.EctoMysqlTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  require Testcontainers.MysqlRepo

  test "can use ecto function" do
    {:ok, container} =
      mysql_container(
        app: :testcontainers,
        migrations_path: "#{__DIR__}/support/migrations",
        repo: Testcontainers.MysqlRepo
      )

    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.TestUser) == []
    Testcontainers.stop_container(container.container_id)
  end
end
