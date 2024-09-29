defmodule Testcontainers.ContainerBuilderHelper do
  import Testcontainers.Constants
  alias Testcontainers.Util.Hash
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  def build(builder, state) when is_map(state) and is_struct(builder) do
    config =
      ContainerBuilder.build(builder)
      |> Container.with_label(container_version_label(), library_version())
      |> Container.with_label(container_lang_label(), container_lang_value())
      |> Container.with_label(container_label(), "#{true}")

    reuse = config.reuse && true == Map.get(state.properties, "testcontainers.reuse.enable", false)

    if reuse do
      hash = Hash.struct_to_hash(config)
      config
      |> Container.with_label(container_reuse(), "true")
      |> Container.with_label(container_reuse_hash_label(), hash)
      |> Container.with_label(container_sessionId_label(), state.session_id)
      |> Kernel.then(&{true, &1, hash})
    else
      config
      |> Container.with_label(container_reuse(), "false")
      |> Container.with_label(container_sessionId_label(), state.session_id)
      |> Kernel.then(&{false, &1, nil})
    end
  end
end
