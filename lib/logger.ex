# SPDX-License-Identifier: MIT
defmodule Testcontainers.Logger do
  @moduledoc """
  Defines an abstraction on top of Elixir.Logger
  """

  require Logger

  import Testcontainers.Constants

  def get_log_level,
    do: Application.get_env(library_name(), :log_level, nil)

  def log(message) when is_binary(message) do
    case get_log_level() do
      nil -> :ok
      level -> Logger.log(level, message)
    end
  end
end
