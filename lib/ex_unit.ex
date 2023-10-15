# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.ExUnit do
  @moduledoc """
  Convenient macros to run containers within ExUnit tests.
  """
  import ExUnit.Callbacks

  alias Testcontainers.Docker

  @doc """
  Sets a container to be created anew for each test in the module.

  It also sets up the ExUnit callback to remove the container after the test has finished.
  """
  defmacro container(name, config) do
    quote do
      require Logger

      setup do
        {:ok, container} = run_container(unquote(config))

        {:ok, %{unquote(name) => container}}
      end
    end
  end

  @doc """
  Sets a container to be created at the beginning of the test module, and shared among all the tests.

  It also sets up the ExUnit callback to remove the container after all the test in the module have finished.
  """
  defmacro shared_container(name, config) do
    quote do
      require Logger

      setup_all do
        {:ok, container} = run_container(unquote(config))

        {:ok, %{unquote(name) => container}}
      end
    end
  end

  @doc """
  Runs a container for a single ExUnit test.

  It also sets up the ExUnit callback to remove the container after the test finishes.
  """
  def run_container(config) do
    Docker.Api.run(config, on_exit: &ExUnit.Callbacks.on_exit/2)
  end
end
