defmodule Testcontainers.NginxTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.WaitStrategy.HttpWaitStrategy
  alias Testcontainers.Container

  @tag timeout: 300_000

  test "creates and uses container" do
    exposed_port = 80

    {:ok, container} =
      Container.new("nginx:latest")
      |> Container.with_exposed_port(exposed_port)
      |> Container.with_waiting_strategy(
        HttpWaitStrategy.new("127.0.0.1", exposed_port, "/", 200, 10000)
      )
      |> run_container()

    host_port = Container.mapped_port(container, exposed_port)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{host_port}")
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.starts_with?(
             body_str,
             "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>"
           )
  end
end
