defprotocol Testcontainers.ContainerBuilder do
  @spec build(t()) :: %Testcontainers.Container{}
  def build(builder)
end
