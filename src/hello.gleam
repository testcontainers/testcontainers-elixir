// SPDX-License-Identifier: Apache-2.0
import gleam/hackney
import gleam/http/request
import gleam/uri
import gleam/option.{None, Option, Some, unwrap}

pub fn fetch_hello(name: String) -> String {
  let assert Ok(request) =
    request.to("https://test-api.service.hmrc.gov.uk/hello/" <> name)

  let assert Ok(response) =
    request
    |> request.prepend_header("accept", "application/vnd.hmrc.1.0+json")
    |> hackney.send

  response.body
}

pub type DockerHost {
  DockerHost(
    scheme: String,
    socket_host: Option(String),
    socket_port: Option(Int),
    host: Option(String),
    port: Option(Int),
  )
}

// a function to parse DOCKER_HOST env var value
// will crash if provided with nil String for docker_host
pub fn parse_docker_host(docker_host: String) -> Option(DockerHost) {
  let assert Ok(uri) = uri.parse(docker_host)
  let assert scheme = unwrap(uri.scheme, "no scheme")
  case scheme {
    "tcp" | "http" ->
      Some(DockerHost(
        scheme: scheme,
        socket_host: None,
        socket_port: None,
        host: uri.host,
        port: uri.port,
      ))
    "unix" | "npipe" ->
      Some(DockerHost(
        scheme: scheme,
        socket_host: Some("localhost"),
        socket_port: Some(2375),
        host: uri.host,
        port: uri.port,
      ))
    _ -> None
  }
}
