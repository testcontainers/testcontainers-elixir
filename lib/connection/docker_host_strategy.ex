# SPDX-License-Identifier: MIT
defprotocol Testcontainers.Connection.DockerHostStrategy do
  @moduledoc """
  Defines the contract that needs to be implemented by docker host strategies
  """

  @doc "Executes the docker_host strategy"
  def execute(strategy, input)
end
