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
    validate_options(options)

    run_block =
      quote do
        {:ok, container} = run_container(unquote(config))

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

  @doc """
  Initiates and manages the lifecycle of a Docker container within the scope of a single ExUnit test.

  This function starts a new container using the provided configuration. It is designed to be used in conjunction with ExUnit's setup callbacks to facilitate the creation of a fresh, isolated environment for each test case. The container is guaranteed to terminate after the test completes, ensuring no carry-over state between tests.

  The function also ensures that necessary prerequisites, such as establishing a connection and starting the reaper process, are handled. This abstraction allows test cases to focus solely on interacting with the container, confident in the knowledge that setup and teardown are managed.

  ## Parameters

    * `config`: A map or keyword list that includes the configuration settings for the container. This includes settings like the image to use, network configuration, bound volumes, exposed ports, and any command or entrypoint overrides.

  ## Examples

  In an ExUnit case, you might use `run_container` in a setup block:

      defmodule MyContainerTest do
        use ExUnit.Case

        alias Testcontainers.Container

        setup do
          # Define container configuration
          config = %Container{image: "my_image", exposed_ports: [80, 443]}

          # Run the container for this test
          {:ok, container} = run_container(config)

          # Pass the container info to the test
          {:ok, container: container}
        end

        test "example test", %{container: container} do
          # Your test logic here, interacting with the container as needed
        end
      end

  ## Notes

    * The container is terminated after the test completes, regardless of the test's outcome, to prevent any state from persisting that might affect subsequent tests.
    * This function is intended for use within ExUnit test cases and might not be suitable for managing containers outside of this context.
  """
  def run_container(config) do
    {:ok, _} = Connection.start_eager()
    {:ok, _} = Reaper.start_eager()
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
