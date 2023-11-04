# SPDX-License-Identifier: MIT
defprotocol Testcontainers.DockerHostStrategy do
  @moduledoc false

  @doc "Executes the docker_host strategy"
  def execute(strategy, input)
end
