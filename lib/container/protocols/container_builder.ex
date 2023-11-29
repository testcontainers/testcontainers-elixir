defprotocol Testcontainers.ContainerBuilder do
  @moduledoc """
  All types of predefined containers must implement this protocol.
  """
  @spec build(t()) :: %Testcontainers.Container{}
  def build(builder)

  @spec is_starting(t(), %Testcontainers.Container{}, %Tesla.Env{}) :: any()
  def is_starting(builder, container, connection)
end
