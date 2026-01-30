Path.wildcard("test/support/**/*.ex")
|> Kernel.ParallelCompiler.compile()

Testcontainers.start_link()

ExUnit.start()

# Application.put_env(:tesla, DockerEngineAPI.Connection,
#   middleware: [{Tesla.Middleware.Logger, log_level: :info}]
# )
