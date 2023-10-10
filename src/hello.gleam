import gleam/hackney
import gleam/http/request

pub fn fetch_hello(name: String) -> String {
  let assert Ok(request) =
    request.to("https://test-api.service.hmrc.gov.uk/hello/" <> name)

  let assert Ok(response) =
    request
    |> request.prepend_header("accept", "application/vnd.hmrc.1.0+json")
    |> hackney.send

  response.body
}
