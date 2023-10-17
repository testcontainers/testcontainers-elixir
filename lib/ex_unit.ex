# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.ExUnit do
  @moduledoc """
  Convenient macros to run containers within ExUnit tests.
  """
  import ExUnit.Callbacks

  alias Testcontainers.Reaper
  alias Testcontainers.Connection
  alias Testcontainers.Container

  @doc """
  Creates and manages the lifecycle of a container within ExUnit tests.

  When the `:shared` option is set to `true`, the container is created once for all tests in the module. It initializes the container before any test is run and keeps it running across multiple tests. This is useful for scenarios where the cost of setting up and tearing down the container is high, or the tests are read-only and won't change the container's state.

  When the `:shared` option is omitted or set to `false`, a new container is created for each individual test, ensuring a clean state for each test case. The container is removed after each test finishes.

  ## Parameters

    * `name`: The key that should be used to reference the container in test cases.
    * `config`: Configuration necessary for initializing the container.
    * `options`: Optional keyword list. Supports the following options:
      * `:shared` - If set to `true`, the container is shared across all tests in the module. If `false`, omitted, or an invalid value is provided, a new container is used for each test.

  ## Examples

  To create a new container for each test:

      defmodule MyTest do
        use ExUnit.Case

        container :my_container, %{image: "my_image"}
        # ...
      end

  To share a container across all tests in the module:

      defmodule MySharedTest do
        use ExUnit.Case

        container :my_shared_container, %{image: "my_shared_image"}, shared: true
        # ...
      end

  ## Notes

    * The macro sets up the necessary ExUnit callbacks to manage the container's lifecycle.
    * It ensures the `Connection` and `Reaper` are started before initializing a container.
    * In the case of shared containers, be mindful that tests can affect the container's state, potentially leading to interdependencies between tests.
  """
  defmacro container(name, config, options \\ []) do
    validate_options(options)

    case Keyword.get(options, :shared, false) do
      true ->
        quote do
          setup_all do
            {:ok, _} = Connection.start_eager()
            {:ok, _} = Reaper.start_eager()

            {:ok, container} = run_container(unquote(config))

            {:ok, %{unquote(name) => container}}
          end
        end

      # stop users from sending invalid values like `shared: NOT_A_BOOL`
      false ->
        quote do
          setup do
            {:ok, _} = Connection.start_eager()
            {:ok, _} = Reaper.start_eager()

            {:ok, container} = run_container(unquote(config))

            {:ok, %{unquote(name) => container}}
          end
        end
    end
  end

  @doc """
  Runs a container for a single ExUnit test.

  It also sets up the ExUnit callback to remove the container after the test finishes.
  """
  def run_container(config) do
    Container.run(config, on_exit: &ExUnit.Callbacks.on_exit/1)
  end

  defp validate_options(options) when is_list(options) do
    Enum.each(options, fn
      {:shared, value} when is_boolean(value) ->
        :ok

      {:shared, _} ->
        raise ArgumentError, "The :shared option must be a boolean"

      {option, _} ->
        raise ArgumentError, "#{option} is not a recognized option"
    end)
  end
end
