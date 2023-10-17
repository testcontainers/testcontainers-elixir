# SPDX-License-Identifier: MIT
defmodule Testcontainers.Connection.DockerHostStrategyEvaluator do
  def run_strategies(strategies, input) do
    Enum.reduce_while(strategies, nil, fn strategy, _acc ->
      case Testcontainers.Connection.DockerHostStrategy.execute(strategy, input) do
        {:ok, _result} = success ->
          {:halt, success}

        error ->
          {:cont, error}
      end
    end)
  end
end
