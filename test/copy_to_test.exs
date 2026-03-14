defmodule CopyToTest do
  alias Testcontainers.HttpWaitStrategy
  use ExUnit.Case, async: true

  test "copy contents to target" do
    port = 80
    contents = "Hello there"

    config =
      %Testcontainers.Container{image: "nginx:alpine"}
      |> Testcontainers.Container.with_exposed_port(port)
      # |> Testcontainers.Container.with_waiting_strategy(HttpWaitStrategy.new("/hello.txt", port))
      |> Testcontainers.Container.with_copy_to("/usr/share/nginx/html/hello.txt", contents)

    assert {:ok, container} = Testcontainers.start_container(config)

    mapped_port = Testcontainers.Container.mapped_port(container, port)
    {:ok, %{body: body}} = Tesla.get("http://127.0.0.1:#{mapped_port}/hello.txt")

    assert contents == body
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
