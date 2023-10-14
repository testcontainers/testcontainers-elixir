# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule TestcontainersElixir.WaitStrategy.CommandWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """
  defstruct [:command]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(command), do: %__MODULE__{command: command}
end

defimpl TestcontainersElixir.WaitStrategy,
  for: TestcontainersElixir.WaitStrategy.CommandWaitStrategy do
  alias TestcontainersElixir.Docker

  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    case Docker.Api.execute_cmd(id_or_name, wait_strategy.command) do
      {:ok, _id} ->
        :ok

      _ ->
        :timer.sleep(100)
        wait_until_container_is_ready(wait_strategy, id_or_name)
    end
  end
end
