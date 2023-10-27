defmodule Testcontainers.Support.MysqlTestUtils do
  alias Testcontainers.Container.MySqlContainer
  alias Testcontainers.Container

  def mysql_connection_parameters_for_test(%Container{} = mysql) do
    try_to_fix_mother_of_all_timeouts = [
      queue_target: 30_000,
      queue_interval: 30_000
    ]

    MySqlContainer.connection_parameters(mysql)
    |> Keyword.merge(try_to_fix_mother_of_all_timeouts)
  end
end
