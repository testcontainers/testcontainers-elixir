defmodule TestContainer.Container.SimpleTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.Container

  container(:httpd, %Container{image: "httpd:latest"}, shared: true)

  test "is created", %{httpd: httpd} do
    assert httpd.image =~ "sha256:"
  end
end
