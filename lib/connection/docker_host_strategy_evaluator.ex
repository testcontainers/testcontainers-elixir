# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerHostStrategyEvaluator do
  @moduledoc false

  def run_strategies(strategies, input) do
    Enum.reduce_while(strategies, nil, fn strategy, _acc ->
      case Testcontainers.DockerHostStrategy.execute(strategy, input) do
        {:ok, _result} = success ->
          {:halt, success}

        error ->
          {:cont, error}
      end
    end)
  end
end
