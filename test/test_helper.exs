{:ok, _} = Testcontainers.Reaper.start_link()
ExUnit.configure(max_cases: System.schedulers_online() * 4)
ExUnit.start()

# Application.put_env(:tesla, DockerEngineAPI.Connection,
#   middleware: [{Tesla.Middleware.Logger, log_level: :info}]
# )
