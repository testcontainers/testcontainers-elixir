defmodule Testcontainers.Container.KafkaContainer do
  @moduledoc """
  Provides functionality for creating and managing Kafka container configurations.
  """

  @default_image "confluentinc/cp-kafka"
  @default_image_with_tag "confluentinc/cp-kafka:6.1.9"
  @default_kafka_port 9092
  @default_broker_port 9093
  @default_zookeeper_port 2181
  @default_wait_timeout 60_000

  @enforce_keys [:image, :kafka_port, :broker_port, :zookeeper_port, :wait_timeout]
  defstruct [:image, :kafka_port, :broker_port, :zookeeper_port, :wait_timeout]

  @doc """
  Creates a new `KafkaContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      kafka_port: @default_kafka_port,
      broker_port: @default_broker_port,
      zookeeper_port: @default_zookeeper_port,
      wait_timeout: @default_wait_timeout
    }
  end

  @doc """
  Overrides the default image used for the Kafka container.
  Right now we support only confluentinc images.
  """
  def with_image(%__MODULE__{} = config, image = @default_image <> ":" <> _tag)
      when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default kafka port used for the Kafka container.
  """
  def with_kafka_port(%__MODULE__{} = config, kafka_port) when is_integer(kafka_port) do
    %{config | kafka_port: kafka_port}
  end

  @doc """
  Overrides the default kafka port used for the Kafka container.
  """
  def with_broker_port(%__MODULE__{} = config, broker_port) when is_integer(broker_port) do
    %{config | broker_port: broker_port}
  end

  @doc """
  Overrides the default zookeeper port used for the Kafka container.
  """
  def with_zookeeper_port(%__MODULE__{} = config, zookeeper_port)
      when is_integer(zookeeper_port) do
    %{config | zookeeper_port: zookeeper_port}
  end

  @doc """
  Overrides the default wait timeout used for the Kafka container.
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end
end
