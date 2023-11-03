defprotocol Testcontainers.Container.Protocols.Builder do
  @spec build(t()) :: %Testcontainers.Container{}
  def build(builder)
end
