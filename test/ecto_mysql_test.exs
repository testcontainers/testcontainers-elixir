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
        repo: Testcontainers.MysqlRepo,
        persistent_volume_name: "testcontainers_ecto_mysql_test"
      )

    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.TestUser) == []
    Testcontainers.stop_container(container.container_id)
  end

  test "fails properly when migrations doesnt pass successfully" do
    assert {:error,
            %MyXQL.Error{
              message:
                "You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'stringa NOT NULL, `hashed_password` varchar(255) NOT NULL, `confirmed_at` dateti' at line 1"
            }} =
             mysql_container(
               app: :testcontainers,
               migrations_path: "#{__DIR__}/support/bad_migrations",
               repo: Testcontainers.MysqlRepo
             )
  end
end
