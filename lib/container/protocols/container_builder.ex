defprotocol Testcontainers.ContainerBuilder do
  @moduledoc """
  All types of predefined containers must implement this protocol.
  """
  @spec build(t()) :: %Testcontainers.Container{}
  def build(builder)

  @doc """
  Do stuff after container has started.
  """
  @spec after_start(t(), %Testcontainers.Container{}, %Tesla.Env{}) :: :ok | {:error, term()}
  def after_start(builder, container, connection)
end
