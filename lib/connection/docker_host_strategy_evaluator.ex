# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategyEvaluator do
  def run_strategies(strategies, input) do
    Enum.reduce_while(strategies, {:error, "No strategy succeeded"}, fn strategy, _acc ->
      case Testcontainers.Connection.DockerHostStrategy.execute(strategy, input) do
        {:ok, _result} = success ->
          # Short-circuit on success
          {:halt, success}

        _error ->
          # Continue to the next strategy, possibly log
          {:cont, {:error, "Strategy failed"}}
      end
    end)
  end
end
