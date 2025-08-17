defmodule Mix.Tasks.Testcontainers.Test do
  use Mix.Task

  @shortdoc "Runs mix test with Testcontainers (backward compatibility)"

  def run(args) do
    Mix.Task.run("testcontainers.run", ["test" | args])
  end
end
