defmodule Testcontainers.ContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Container

  describe "with_auth/3" do
    test "sets the authentication token for the container" do
      container = Container.new("my-image")
      assert container.auth == nil

      updated_container = Container.with_auth(container, "username", "password")

      assert updated_container.auth ==
               "eyJwYXNzd29yZCI6InBhc3N3b3JkIiwidXNlcm5hbWUiOiJ1c2VybmFtZSJ9"
    end
  end
end
