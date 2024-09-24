defmodule Testcontainers.Constants do
  @moduledoc false

  def library_name, do: :testcontainers
  def library_version, do: "1.9.0"
  def container_label, do: "org.testcontainers"
  def container_lang_label, do: "org.testcontainers.lang"
  def container_reuse_hash_label, do: "org.testcontainers.reuse-hash"
  def container_reuse, do: "org.testcontainers.reuse"
  def container_lang_value, do: Elixir |> Atom.to_string() |> String.downcase()
  def container_sessionId_label, do: "org.testcontainers.session-id"
  def container_version_label, do: "org.testcontainers.version"
  def user_agent, do: "tc-elixir/" <> __MODULE__.library_version()
end
