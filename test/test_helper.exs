import Testcontainers.ExUnit
alias Testcontainers.Container
alias Container.PostgresContainer

# for testing that it works, not used anywhere
postgres =
  PostgresContainer.new("postgres:latest")
  |> Container.with_fixed_port(5432, 2345)

{:ok, _} = run_container(postgres, on_exit: nil)

ExUnit.configure(max_cases: System.schedulers_online() * 4)
ExUnit.start()

# Application.put_env(:tesla, DockerEngineAPI.Connection,
#   middleware: [{Tesla.Middleware.Logger, log_level: :info}]
# )
