# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.ExUnit do
  @moduledoc """
  Convenient macros to run containers within ExUnit tests.
  """
  import ExUnit.Callbacks

  alias Testcontainers.Container

  @doc """
  Creates and manages the lifecycle of a container within ExUnit tests.

  When the `:shared` option is set to `true`, the container is created once for all tests in the module. It initializes the container before any test is run and keeps it running across multiple tests. This is useful for scenarios where the cost of setting up and tearing down the container is high, or the tests are read-only and won't change the container's state.

  When the `:shared` option is omitted or set to `false`, a new container is created for each individual test, ensuring a clean state for each test case. The container is removed after each test finishes.

  ## Parameters

    * `name`: The key that should be used to reference the container in test cases.
    * `config`: Configuration necessary for initializing the container.
    * `options`: Optional keyword list. Supports the following options:
      * `:shared` - If set to `true`, the container is shared across all tests in the module. If `false` or omitted, a new container is used for each test.

  ## Examples

  To create a new container for each test:

      defmodule MyTest do
        use ExUnit.Case

        alias Testcontainers.Container

        container :my_container, %Container{image: "my_image"}
        # ...
      end

  To share a container across all tests in the module:

      defmodule MySharedTest do
        use ExUnit.Case

        alias Testcontainers.Container

        container :my_shared_container, %Container{image: "my_shared_image"}, shared: true
        # ...
      end

  ## Notes

    * The macro sets up the necessary ExUnit callbacks to manage the container's lifecycle.
    * It ensures the `Connection` and `Reaper` are started before initializing a container.
    * In the case of shared containers, be mindful that tests can affect the container's state, potentially leading to interdependencies between tests.
  """
  defmacro container(name, config, options \\ []) do
    run_block =
      quote do
        {:ok, container} = Container.run(unquote(config), on_exit: &ExUnit.Callbacks.on_exit/1)

        {:ok, %{unquote(name) => container}}
      end

    case Keyword.get(options, :shared, false) do
      true ->
        quote do
          setup_all do
            unquote(run_block)
          end
        end

      _ ->
        quote do
          setup do
            unquote(run_block)
          end
        end
    end
  end
end
