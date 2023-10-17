# SPDX-License-Identifier: MIT
defmodule Testcontainers.Utils do
  @moduledoc """
  Defines constants and functions shared across modules in `Testcontainers`.
  """

  require Logger

  @library_name :testcontainers
  @default_log_level nil

  def library_name, do: @library_name

  def get_log_level,
    do: Application.get_env(library_name(), :log_level, @default_log_level)

  def log(message) when is_binary(message) do
    case get_log_level() do
      nil -> :ok
      level -> Logger.log(level, message)
    end
  end
end
