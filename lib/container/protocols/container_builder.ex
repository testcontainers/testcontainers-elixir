defprotocol Testcontainers.ContainerBuilder do
  @moduledoc """
  All types of predefined containers must implement this protocol.
  """
  @spec build(t()) :: %Testcontainers.Container{}
  def build(builder)
end
