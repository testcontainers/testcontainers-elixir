# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defprotocol Testcontainers.WaitStrategy do
  @moduledoc """
  Defines the protocol/interface for the wait strategies in `Testcontainers`
  """
  alias Testcontainers.Container

  # TODO send inn the Container struct instead of id_or_name
  # TODO also in Testcontainers, dont send in id for stdout_logs, exec_create etc,
  # but send the Container struct, because we should already have a container
  @spec wait_until_container_is_ready(t(), %Container{}) :: :ok | {:error, atom()}
  def wait_until_container_is_ready(wait_strategy, container)
end
