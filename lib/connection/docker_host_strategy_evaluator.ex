# SPDX-License-Identifier: MIT
defmodule Testcontainers.DockerHostStrategyEvaluator do
  @moduledoc false

  def run_strategies(strategies, input) do
    Enum.reduce_while(strategies, [], fn strategy, acc ->
      case Testcontainers.DockerHostStrategy.execute(strategy, input) do
        {:ok, _result} = success ->
          {:halt, success}

        error ->
          {:cont, [error | acc]}
      end
    end)
    |> case do
      {:ok, _} = success ->
        success

      errors when is_list(errors) ->
        {:error, "Failed to find docker host: #{format_errors(errors)}"}
    end
  end

  defp format_errors(errors) do
    errors
    |> Enum.reverse()
    |> Enum.map(fn {:error, error} -> inspect(error) end)
    |> Enum.join(", ")
  end
end
