defmodule SimpleTest do
  use ExUnit.Case, async: true

  import TestcontainersElixir.ExUnit

  alias TestcontainersElixir.HttpChecker
  alias TestcontainersElixir.Container

  test "creates and uses container" do
    {:ok, container} = container(image: "nginx:latest", port: 80)

    port = Container.mapped_port(container, 80)

    {:ok, :http_is_ready} = HttpChecker.wait_for_http("127.0.0.1", port, "/", 5000)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{port}")
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.starts_with?(
             body_str,
             "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>"
           )
  end
end
