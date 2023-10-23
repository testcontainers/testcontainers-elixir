# SPDX-License-Identifier: MIT
defmodule Testcontainers.WaitStrategy.HttpWaitStrategy do
  @moduledoc """
  Awaits a successful HTTP response from the container.
  """

  @retry_delay 200

  defstruct [:ip, :port, :path, :status_code, :timeout, retry_delay: @retry_delay]

  @doc """
  Creates a new HttpWaitStrategy to wait until a successful HTTP response is received from the container.
  """
  def new(
        ip,
        port,
        path \\ "/",
        status_code \\ 200,
        timeout \\ 5000,
        retry_delay \\ @retry_delay
      ),
      do: %__MODULE__{
        ip: ip,
        port: port,
        path: path,
        status_code: status_code,
        timeout: timeout,
        retry_delay: retry_delay
      }

  defimpl Testcontainers.WaitStrategy do
    alias Testcontainers.Container
    alias Testcontainers.WaitStrategy.HttpWaitStrategy
    alias Testcontainers.Utils

    @impl true
    def wait_until_container_is_ready(%HttpWaitStrategy{} = wait_strategy, container_id) do
      with {:ok, %Container{} = container} <- Testcontainers.get_container(container_id) do
        host_port = Container.mapped_port(container, wait_strategy.port)

        case wait_for_http(
               wait_strategy,
               container_id,
               host_port,
               current_time_millis()
             ) do
          {:ok, :http_is_ready} ->
            :ok

          {:error, reason} ->
            {:error, reason, wait_strategy}
        end
      end
    end

    defp wait_for_http(%HttpWaitStrategy{} = wait_strategy, container_id, host_port, start_time)
         when is_integer(host_port) and is_integer(start_time) do
      if wait_strategy.timeout + start_time < current_time_millis() do
        {:error, strategy_timed_out(wait_strategy.timeout, start_time)}
      else
        case http_request(
               wait_strategy.ip,
               host_port,
               wait_strategy.path,
               wait_strategy.status_code
             ) do
          {:ok, _response} ->
            {:ok, :http_is_ready}

          {:error, _reason} ->
            delay = max(0, wait_strategy.retry_delay)

            Utils.log(
              "Http endpoint #{"http://#{wait_strategy.ip}:#{host_port}#{wait_strategy.path}"} in container #{container_id} didnt respond with #{wait_strategy.status_code}, retrying in #{delay}ms."
            )

            :timer.sleep(delay)
            wait_for_http(wait_strategy, container_id, host_port, start_time)
        end
      end
    end

    defp http_request(ip, port, path, expected_status_code)
         when is_integer(expected_status_code) do
      url = "http://" <> ip <> ":" <> Integer.to_string(port) <> path

      case :httpc.request(:get, {to_charlist(url), []}, [], []) do
        {:ok, {{~c"HTTP/1.1", ^expected_status_code, _reason_phrase}, _headers, _body}} ->
          {:ok, :http_ok}

        {:ok, {{~c"HTTP/1.1", status_code, _reason_phrase}, _headers, _body}}
        when status_code != expected_status_code ->
          {:error, {:unexpected_status_code, status_code}}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp current_time_millis, do: System.monotonic_time(:millisecond)

    defp strategy_timed_out(timeout, started_at)
         when is_number(timeout) and is_number(started_at),
         do:
           {:http_wait_strategy, :timeout, timeout,
            elapsed_time: current_time_millis() - started_at}
  end
end
