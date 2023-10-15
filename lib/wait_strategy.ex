# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defprotocol Testcontainers.WaitStrategy do
  @moduledoc false

  @spec wait_until_container_is_ready(t, String.t()) :: :ok | {:error, atom()}
  def wait_until_container_is_ready(wait_strategy, id_or_name)
end
