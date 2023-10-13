defmodule AnotherTest do
  use ExUnit.Case, async: true

  alias TestcontainersElixir.HttpChecker
  alias TestcontainersElixir.Container

  test "creates and uses container" do
    {:ok, container} =
      %Container{
        image: "httpd:latest",
        exposed_ports: [80]
      }
      |> Container.run(
        on_exit: &ExUnit.Callbacks.on_exit/2,
        waiting_strategy: fn _, container ->
          HttpChecker.wait_for_http(
            "127.0.0.1",
            Container.mapped_port(container, 80),
            "/",
            5000
          )
        end
      )

    port = Container.mapped_port(container, 80)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{port}")
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.contains?(
             body_str,
             "<html><body><h1>It works!</h1></body></html>\n"
           )
  end
end
