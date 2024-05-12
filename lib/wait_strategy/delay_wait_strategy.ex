# SPDX-License-Identifier: MIT
defmodule Testcontainers.DelayWaitStrategy do
  @moduledoc """
  Considers the container as ready when a certain time has passed.
  """

  defstruct [:timeout]

  def new(timeout) do
    %__MODULE__{timeout: timeout}
  end

  defimpl Testcontainers.WaitStrategy do
    @impl true
    def wait_until_container_is_ready(wait_strategy, _container, _conn) do
      :timer.sleep(wait_strategy.timeout)
      :ok
    end
  end
end
