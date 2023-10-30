defmodule TestHelper do
  @doc """
  Waits for the specified GenServer to change its running state (either start or stop).

  ## Parameters
  - server: The server's registered name.
  - state: Desired state to wait for (:up or :down).
  - opts: Options including :max_retries and :interval (both optional).

  ## Examples
      TestHelper.wait_for_genserver_state(:my_server, :up)
      TestHelper.wait_for_genserver_state(:my_server, :down, max_retries: 5, interval: 200)
  """
  def wait_for_genserver_state(server, state, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 10)
    interval = Keyword.get(opts, :interval, 100)

    do_wait_for_state(server, state, max_retries, interval, 0)
  end

  defp do_wait_for_state(_server, _state, 0, _interval, counter) do
    raise "GenServer did not reach the desired state after #{counter} checks."
  end

  defp do_wait_for_state(server, state, retries, interval, counter) do
    current_state = if GenServer.whereis(server), do: :up, else: :down

    if current_state == state do
      :ok
    else
      Process.sleep(interval)
      do_wait_for_state(server, state, retries - 1, interval, counter + 1)
    end
  end

  @doc """
  Waits for the provided lambda to return :ok.

  ## Parameters
  - lambda: The lambda to be invoked.
  - opts: Options including :max_retries and :interval (both optional).

  ## Examples
      TestHelper.wait_for_lambda(fn -> perform_check() end)
      TestHelper.wait_for_lambda(fn -> perform_check() end, max_retries: 5, interval: 200)

  ## Note
  The lambda should return :ok when the desired state is reached.
  """
  def wait_for_lambda(lambda, opts \\ []) when is_function(lambda, 0) do
    max_retries = Keyword.get(opts, :max_retries, 10)
    interval = Keyword.get(opts, :interval, 100)

    do_wait_for_lambda(lambda, max_retries, interval, 0)
  end

  defp do_wait_for_lambda(_lambda, 0, _interval, counter) do
    raise "Lambda did not return :ok after #{counter} retries."
  end

  defp do_wait_for_lambda(lambda, retries, interval, counter) do
    case lambda.() do
      :ok ->
        :ok

      _other ->
        Process.sleep(interval)
        do_wait_for_lambda(lambda, retries - 1, interval, counter + 1)
    end
  end
end
