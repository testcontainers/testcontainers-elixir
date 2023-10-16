defmodule Testcontainers.Constants do
  @moduledoc """
  Defines constants shared across modules in `Testcontainers`.
  """

  @doc """
  Provides the standard library name used for configuration, logging, etc.
  """
  @library_name :testcontainers
  @default_log_level :debug

  def library_name, do: @library_name

  def get_log_level,
    do: Application.get_env(library_name(), :log_level, @default_log_level)
end
