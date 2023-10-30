# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defprotocol Testcontainers.WaitStrategy do
  @moduledoc """
  Defines the protocol/interface for the wait strategies in `Testcontainers`
  """
  alias Testcontainers.Container

  @spec wait_until_container_is_ready(t(), %Container{}, Tesla.Env.client()) ::
          :ok | {:error, atom()}
  def wait_until_container_is_ready(wait_strategy, container, conn)
end
