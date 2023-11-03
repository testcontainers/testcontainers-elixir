defmodule ElixirSampleProjectWithTestcontainersTest do
  use ExUnit.Case
  doctest ElixirSampleProjectWithTestcontainers
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.Container.MySqlContainer

  container(:mysql, MySqlContainer.new(), shared: true)

  test "asserts mysql container major version", %{mysql: mysql} do
    assert Container.mapped_port(mysql, 3306) > 1
  end

  test "greets the world" do
    assert ElixirSampleProjectWithTestcontainers.hello() == :world
  end
end
