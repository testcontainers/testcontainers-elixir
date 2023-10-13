defmodule SimpleTest do
  use ExUnit.Case
  import TestcontainersElixir.ExUnit
  alias TestcontainersElixir.PortChecker
  alias TestcontainersElixir.Container

  test "creates and reaps container" do
    {:ok, container} = container(image: "nginx:latest", port: 80)

    port = Container.mapped_port(container, 80)
    {:ok, :port_is_open} = PortChecker.wait_for_port("127.0.0.1", port, 5000)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{port}", [follow_redirect: true, max_redirect: 5, force_redirect: true])
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.contains?(
             body_str,
             "<!DOCTYPE html>\n<html>\n<head>\n<title>Welcome to nginx!</title>\n<style>\nhtml { color-scheme: light dark; }\nbody { width: 35em; margin: 0 auto;\nfont-family: Tahoma, Verdana, Arial, sans-serif; }\n</style>\n</head>\n<body>\n<h1>Welcome to nginx!</h1>\n<p>If you see this page, the nginx web server is successfully installed and\nworking. Further configuration is required.</p>\n\n<p>For online documentation and support please refer to\n<a href=\"http://nginx.org/\">nginx.org</a>.<br/>\nCommercial support is available at\n<a href=\"http://nginx.com/\">nginx.com</a>.</p>\n\n<p><em>Thank you for using nginx.</em></p>\n</body>\n</html>\n"
           )
  end
end
