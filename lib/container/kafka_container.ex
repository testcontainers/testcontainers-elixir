defmodule Testcontainers.KafkaContainer do
  @moduledoc """
  Provides functionality for creating and managing Kafka container configurations.
  """
  alias Testcontainers.Container
  alias Testcontainers.KafkaContainer
  alias Testcontainers.CommandWaitStrategy

  @default_image "confluentinc/cp-kafka"
  @default_image_with_tag "#{@default_image}:7.4.3"
  @default_kafka_port 9092
  @default_broker_port 29092
  @default_zookeeper_port 2181
  @default_wait_timeout 60_000
  @default_consensus_strategy :zookeeper_embedded
  @default_topic_partitions 1

  @enforce_keys [
    :image,
    :kafka_port,
    :broker_port,
    :zookeeper_port,
    :zookeeper_host,
    :wait_timeout,
    :consensus_strategy,
    :default_topic_partitions
  ]
  defstruct [
    :image,
    :kafka_port,
    :broker_port,
    :zookeeper_port,
    :zookeeper_host,
    :wait_timeout,
    :consensus_strategy,
    :default_topic_partitions
  ]

  @doc """
  Creates a new `KafkaContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      kafka_port: @default_kafka_port,
      broker_port: @default_broker_port,
      zookeeper_port: @default_zookeeper_port,
      wait_timeout: @default_wait_timeout,
      consensus_strategy: @default_consensus_strategy,
      zookeeper_host: nil,
      default_topic_partitions: @default_topic_partitions
    }
  end

  @doc """
  Overrides the default image used for the Kafka container.
  Right now we support only confluentinc images.
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
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
  Overrides the default consensus strategy used for the Kafka container.
  """
  def with_consensus_strategy(%__MODULE__{} = config, consensus_strategy)
      when consensus_strategy in [:zookeeper_embedded, :zookeeper_external, :kraft] do
    %{config | consensus_strategy: consensus_strategy}
  end

  @doc """
  Overrides the default zookeeper port used for the Kafka container.
  """
  def with_zookeeper_port(%__MODULE__{consensus_strategy: strategy} = config, zookeeper_port)
      when is_integer(zookeeper_port) and strategy in [:zookeeper_embedded, :zookeeper_external] do
    %{config | zookeeper_port: zookeeper_port}
  end

  @doc """
  Overrides the default zookeeper host used for the Kafka container.
  Available only when zookeeper_strategy is external
  """
  def with_zookeeper_host(
        %__MODULE__{consensus_strategy: :zookeeper_external} = config,
        zookeeper_host
      )
      when is_binary(zookeeper_host) do
    %{config | zookeeper_host: zookeeper_host}
  end

  @doc """
  Overrides the default wait timeout used for the Kafka container.
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Overrides the default topic
  """
  def with_topic_partitions(%__MODULE__{} = config, topic_partitions)
      when is_integer(topic_partitions) do
    %{config | default_topic_partitions: topic_partitions}
  end

  defimpl Testcontainers.ContainerBuilder do
    import Container

    @impl true
    @spec build(%KafkaContainer{}) :: %Container{}
    def build(%KafkaContainer{} = config) do
      new(config.image)
      |> with_fixed_port(config.kafka_port)
      |> with_environment(:KAFKA_BROKER_ID, "1")
      |> with_listener_config(config)
      |> with_topic_config(config)
      |> with_startup_script(config)
      |> with_waiting_strategies([
        CommandWaitStrategy.new(
          ["kafka-topics", "--bootstrap-server", "localhost:#{config.kafka_port}", "--list"],
          config.wait_timeout,
          1000
        ),
        CommandWaitStrategy.new(
          ["kafka-broker-api-versions", "--bootstrap-server", "localhost:#{config.kafka_port}"],
          config.wait_timeout,
          1000
        )
      ])
    end

    # ------------------Listeners------------------
    defp with_listener_config(container, config) do
      container
      |> with_environment(
        :KAFKA_LISTENERS,
        "BROKER://0.0.0.0:#{config.broker_port},OUTSIDE://0.0.0.0:#{config.kafka_port}"
      )
      |> with_environment(
        :KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
        "BROKER:PLAINTEXT,OUTSIDE:PLAINTEXT"
      )
      |> with_environment(:KAFKA_INTER_BROKER_LISTENER_NAME, "BROKER")
    end

    defp with_topic_config(container, _config) do
      container
      |> with_environment(:KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR, "1")
      |> with_environment(:KAFKA_OFFSETS_TOPIC_NUM_PARTITIONS, "1")
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR, "1")
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_MIN_ISR, "1")
      |> with_environment(:KAFKA_AUTO_CREATE_TOPICS_ENABLE, "false")
    end

    # ------------------Startup------------------
    defp with_startup_script(container, config) do
      script = container |> build_startup_script(config)

      command =
        String.split(script, "\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      with_cmd(container, ["sh", "-c", command])
    end

    defp build_startup_script(container, config) do
      container
      |> init_script(config)
      |> consensus_strategy_command(config)
    end

    defp consensus_strategy_command(script, config) do
      case config.consensus_strategy do
        :zookeeper_embedded -> embedded_zookeeper_script(script, config)
        :zookeeper_external -> external_zookeeper_script(script, config)
        value -> raise "Consensus strategy #{inspect(value)} not implemented"
      end
    end

    defp embedded_zookeeper_script(script, config) do
      """
      #{script}
      export KAFKA_ZOOKEEPER_CONNECT='localhost:#{config.zookeeper_port}'
      echo 'clientPort=#{config.zookeeper_port}' > zookeeper.properties
      echo 'dataDir=/var/lib/zookeeper/data' >> zookeeper.properties
      echo 'dataLogDir=/var/lib/zookeeper/log' >> zookeeper.properties
      zookeeper-server-start zookeeper.properties &
      /etc/confluent/docker/run
      """
    end

    defp external_zookeeper_script(script, config) do
      """
      #{script}
      export KAFKA_ZOOKEEPER_CONNECT='#{config.zookeeper_host}:#{config.zookeeper_port}'
      /etc/confluent/docker/run
      """
    end

    # ----------------------- Default -----------------------
    defp init_script(_container, config) do
      internal = "BROKER://$(hostname -i):#{config.broker_port}"
      external = "OUTSIDE://#{Testcontainers.get_host()}:#{config.kafka_port}"

      """
      export KAFKA_ADVERTISED_LISTENERS=#{internal},#{external}
      echo '' > /etc/confluent/docker/ensure
      """
    end
  end
end
