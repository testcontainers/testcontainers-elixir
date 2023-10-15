defmodule Testcontainers.HttpdTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.HttpWaitStrategy

  test "creates and uses container" do
    exposed_port = 80

    {:ok, container} =
      Container.new("httpd:latest")
      |> Container.with_exposed_port(exposed_port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("127.0.0.1", exposed_port, "/", 10000)
      )
      |> run_container()

    host_port = Container.mapped_port(container, 80)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{host_port}")
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.contains?(
             body_str,
             "<html><body><h1>It works!</h1></body></html>\n"
           )
  end
end
