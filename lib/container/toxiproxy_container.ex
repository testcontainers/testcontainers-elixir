# SPDX-License-Identifier: MIT
defmodule Testcontainers.ToxiproxyContainer do
  @moduledoc """
  Provides functionality for creating and managing Toxiproxy container configurations.

  Toxiproxy is a framework for simulating network conditions. It's made specifically
  to work in testing, CI and development environments, supporting deterministic tampering
  with connections, but with support for randomized chaos and customization.
  """

  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.PortWaitStrategy
  alias Testcontainers.ToxiproxyContainer

  @default_image "ghcr.io/shopify/toxiproxy"
  @default_tag "2.9.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"

  # Toxiproxy control/API port
  @control_port 8474

  @first_proxy_port 8666
  @proxy_port_count 31

  @default_wait_timeout 60_000

  @enforce_keys [:image, :wait_timeout]
  defstruct [:image, :wait_timeout, check_image: @default_image, reuse: false]

  @doc """
  Creates a new `ToxiproxyContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: @default_wait_timeout
    }
  end

  @doc """
  Overrides the default image used for the Toxiproxy container.
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default wait timeout used for the Toxiproxy container.
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  @doc """
  Retrieves the default Docker image for the Toxiproxy container.
  """
  def default_image, do: @default_image_with_tag

  @doc """
  Returns the control port number (for the Toxiproxy HTTP API).
  """
  def control_port, do: @control_port

  @doc """
  Returns the first proxy port number.
  """
  def first_proxy_port, do: @first_proxy_port

  @doc """
  Returns the mapped control port on the host for the running container.
  """
  def mapped_control_port(%Container{} = container) do
    Container.mapped_port(container, @control_port)
  end

  @doc """
  Returns the URI for the Toxiproxy API.

  This can be used with ToxiproxyEx:

      ToxiproxyContainer.api_url(container)
      |> then(&Application.put_env(:toxiproxy_ex, :host, &1))
  """
  def api_url(%Container{} = container) do
    host = Testcontainers.get_host()
    port = mapped_control_port(container)
    "http://#{host}:#{port}"
  end

  @doc """
  Configures the ToxiproxyEx library to use this container.

  This sets the `:toxiproxy_ex` application environment to point to
  the running container's API endpoint.

  ## Example

      {:ok, toxiproxy} = Testcontainers.start_container(ToxiproxyContainer.new())
      :ok = ToxiproxyContainer.configure_toxiproxy_ex(toxiproxy)

      # Now ToxiproxyEx will use this container
      ToxiproxyEx.get!("my_proxy") |> ToxiproxyEx.down!(fn -> ... end)
  """
  def configure_toxiproxy_ex(%Container{} = container) do
    Application.put_env(:toxiproxy_ex, :host, api_url(container))
    :ok
  end

  @doc """
  Creates a proxy in Toxiproxy that routes traffic from a container port to an upstream service.

  ## Parameters

  - `container` - The running Toxiproxy container
  - `name` - A unique name for the proxy
  - `upstream` - The upstream address in format "host:port" (as seen from Toxiproxy container)
  - `opts` - Optional keyword list:
    - `:listen_port` - Specific port to listen on (default: auto-allocated from 8666+)
  """
  def create_proxy(%Container{} = container, name, upstream, opts \\ []) do
    listen_port = Keyword.get(opts, :listen_port, @first_proxy_port)

    host = Testcontainers.get_host()
    api_port = mapped_control_port(container)

    :inets.start()

    url = ~c"http://#{host}:#{api_port}/proxies"

    body =
      Jason.encode!(%{
        name: name,
        listen: "0.0.0.0:#{listen_port}",
        upstream: upstream
      })

    headers = [{~c"content-type", ~c"application/json"}]

    case :httpc.request(:post, {url, headers, ~c"application/json", body}, [], []) do
      {:ok, {{_, code, _}, _, _}} when code in [200, 201] ->
        # Return the mapped port on the host
        {:ok, Container.mapped_port(container, listen_port)}

      {:ok, {{_, 409, _}, _, _}} ->
        # Proxy already exists, return the port
        {:ok, Container.mapped_port(container, listen_port)}

      {:ok, {{_, code, _}, _, response_body}} ->
        {:error, {:http_error, code, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a proxy for another container on the same network.

  This is a convenience function that creates a proxy using the target container's
  hostname and port.

  ## Parameters

  - `toxiproxy` - The running Toxiproxy container
  - `name` - A unique name for the proxy
  - `target_container` - The target container to proxy to
  - `target_port` - The port on the target container
  - `opts` - Optional keyword list (see `create_proxy/4`)
  """
  def create_proxy_for_container(
        %Container{} = toxiproxy,
        name,
        %Container{} = target_container,
        target_port,
        opts \\ []
      ) do
    # Use the target container's IP address on the Docker network
    upstream = "#{target_container.ip_address}:#{target_port}"
    create_proxy(toxiproxy, name, upstream, opts)
  end

  @doc """
  Deletes a proxy from Toxiproxy.
  """
  def delete_proxy(%Container{} = container, name) do
    host = Testcontainers.get_host()
    api_port = mapped_control_port(container)

    :inets.start()

    url = ~c"http://#{host}:#{api_port}/proxies/#{name}"

    case :httpc.request(:delete, {url, []}, [], []) do
      {:ok, {{_, 204, _}, _, _}} -> :ok
      {:ok, {{_, 404, _}, _, _}} -> {:error, :not_found}
      {:ok, {{_, code, _}, _, body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resets Toxiproxy, removing all toxics and re-enabling all proxies.
  """
  def reset(%Container{} = container) do
    host = Testcontainers.get_host()
    api_port = mapped_control_port(container)

    :inets.start()

    url = ~c"http://#{host}:#{api_port}/reset"

    case :httpc.request(:post, {url, [], ~c"application/json", "{}"}, [], []) do
      {:ok, {{_, 204, _}, _, _}} -> :ok
      {:ok, {{_, code, _}, _, body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all proxies configured in Toxiproxy.

  Returns a map of proxy names to their configurations.
  """
  def list_proxies(%Container{} = container) do
    host = Testcontainers.get_host()
    api_port = mapped_control_port(container)

    :inets.start()

    url = ~c"http://#{host}:#{api_port}/proxies"

    case :httpc.request(:get, {url, []}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, Jason.decode!(to_string(body))}

      {:ok, {{_, code, _}, _, body}} ->
        {:error, {:http_error, code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the number of proxy ports reserved.
  """
  def proxy_port_count, do: @proxy_port_count

  # ContainerBuilder implementation
  defimpl ContainerBuilder do
    import Container

    @impl true
    def build(%ToxiproxyContainer{} = config) do
      # Build list of ports to expose: control port + proxy ports
      proxy_ports =
        Enum.to_list(
          ToxiproxyContainer.first_proxy_port()..(ToxiproxyContainer.first_proxy_port() +
                                                    ToxiproxyContainer.proxy_port_count() - 1)
        )

      all_ports = [ToxiproxyContainer.control_port() | proxy_ports]

      new(config.image)
      |> with_exposed_ports(all_ports)
      |> with_waiting_strategy(
        PortWaitStrategy.new(
          "127.0.0.1",
          ToxiproxyContainer.control_port(),
          config.wait_timeout
        )
      )
      |> with_reuse(config.reuse)
    end

    @impl true
    def after_start(_config, _container, _conn), do: :ok
  end
end
