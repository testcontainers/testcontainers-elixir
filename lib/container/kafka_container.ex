defmodule Testcontainers.KafkaContainer do
  @moduledoc """
  Provides functionality for creating and managing Kafka container configurations.
  """
  alias Testcontainers.Container
  alias Testcontainers.Docker
  alias Testcontainers.KafkaContainer
  alias Testcontainers.CommandWaitStrategy

  @default_image "confluentinc/cp-kafka"
  @default_image_with_tag "#{@default_image}:7.4.3"
  @default_kafka_port 9092
  @default_broker_port 29092
  @default_broker_id 1
  @default_zookeeper_port 2181
  @default_wait_timeout 60_000
  @default_consensus_strategy :zookeeper_embedded
  @default_topic_partitions 1
  @default_cluster_id "4L6g3nShT-eMCtK--X86sw"

  @start_file_path "tc-start.sh"

  @enforce_keys [
    :image,
    :kafka_port,
    :broker_port,
    :broker_id,
    :zookeeper_port,
    :zookeeper_host,
    :cluster_id,
    :wait_timeout,
    :consensus_strategy,
    :default_topic_partitions,
    :start_file_path
  ]
  defstruct [
    :image,
    :kafka_port,
    :broker_port,
    :broker_id,
    :cluster_id,
    :zookeeper_port,
    :zookeeper_host,
    :wait_timeout,
    :consensus_strategy,
    :default_topic_partitions,
    :start_file_path,
    reuse: false
  ]

  @doc """
  Creates a new `KafkaContainer` struct with default configurations.
  """
  def new do
    %__MODULE__{
      image: @default_image_with_tag,
      kafka_port: @default_kafka_port,
      broker_port: @default_broker_port,
      broker_id: @default_broker_id,
      zookeeper_port: @default_zookeeper_port,
      cluster_id: @default_cluster_id,
      wait_timeout: @default_wait_timeout,
      consensus_strategy: @default_consensus_strategy,
      zookeeper_host: nil,
      default_topic_partitions: @default_topic_partitions,
      start_file_path: @start_file_path
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
  Overrides the default broker id used for the Kafka container.
  """
  def with_broker_id(%__MODULE__{} = config, broker_id) when is_integer(broker_id) do
    %{config | broker_id: broker_id}
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
  Available only when consensus_strategy is external
  """
  def with_zookeeper_host(
        %__MODULE__{consensus_strategy: :zookeeper_external} = config,
        zookeeper_host
      )
      when is_binary(zookeeper_host) do
    %{config | zookeeper_host: zookeeper_host}
  end

  @doc """
  Overrides the default zookeeper host used for the Kafka container.
  Available only when consensus_strategy is kraft
  """
  def with_cluster_id(%__MODULE__{consensus_strategy: :kraft} = config, cluster_id)
      when is_binary(cluster_id) do
    %{config | cluster_id: cluster_id}
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

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  defimpl Testcontainers.ContainerBuilder do
    import Container

    @impl true
    @spec build(%KafkaContainer{}) :: %Container{}
    def build(%KafkaContainer{} = config) do
      new(config.image)
      |> with_exposed_port(config.kafka_port)
      |> with_listener_config(config)
      |> with_topic_config(config)
      |> with_startup_script(config)
      |> with_reuse(config.reuse)
      |> with_waiting_strategy(
        CommandWaitStrategy.new(
          ["kafka-broker-api-versions", "--bootstrap-server", "localhost:#{config.kafka_port}"],
          config.wait_timeout,
          1000
        )
      )
    end

    @doc """
    Do stuff after container has started.
    We now know both the host and the port of the container and we can
    assign them to the config.
    """
    @impl true
    @spec after_start(%KafkaContainer{}, %Testcontainers.Container{}, %Tesla.Env{}) :: :ok
    def after_start(config = %{start_file_path: start_file_path}, container, conn) do
      with script <- build_startup_script(container, config),
           {:ok, _} <-
             Docker.Api.put_file(container.container_id, conn, "/", start_file_path, script) do
        :ok
      end
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

    # ------------------Topics------------------
    defp with_topic_config(container, config) do
      container
      |> with_environment(:KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR, "1")
      |> with_environment(
        :KAFKA_OFFSETS_TOPIC_NUM_PARTITIONS,
        "#{config.default_topic_partitions}"
      )
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR, "1")
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_MIN_ISR, "1")
      |> with_environment(:KAFKA_AUTO_CREATE_TOPICS_ENABLE, "false")
    end

    # ------------------Startup------------------
    defp with_startup_script(container, %{start_file_path: start_file_path}) do
      with_cmd(container, [
        "sh",
        "-c",
        "while [ ! -f /#{start_file_path} ]; do echo 'ok' && sleep 0.1; done; sh /#{start_file_path};"
      ])
    end

    # ------------------Startup Script------------------
    defp build_startup_script(container, config) do
      container
      |> init_script(config)
      |> add_consensus_strategy(container, config)
      |> add_run_command()
      |> parse_script()
    end

    defp add_consensus_strategy(script, container, config) do
      case config.consensus_strategy do
        :zookeeper_embedded -> embedded_zookeeper_script(script, config)
        :zookeeper_external -> external_zookeeper_script(script, config)
        :kraft -> kraft_script(script, container, config)
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
      """
    end

    defp external_zookeeper_script(script, config) do
      """
      #{script}
      export KAFKA_ZOOKEEPER_CONNECT='#{config.zookeeper_host}:#{config.zookeeper_port}'
      """
    end

    # Currently we support only single node as QUORUM_VOTERS requires to know hostnames
    # of all voters
    defp kraft_script(script, container, config) do
      listeners = Map.fetch!(container.environment, :KAFKA_LISTENERS)
      protocol_map = Map.fetch!(container.environment, :KAFKA_LISTENER_SECURITY_PROTOCOL_MAP)

      """
      #{script}
      export CLUSTER_ID=#{config.cluster_id}
      export KAFKA_NODE_ID=#{config.broker_id}
      export KAFKA_PROCESS_ROLES=broker,controller
      export KAFKA_LISTENERS=#{listeners},CONTROLLER://0.0.0.0:9094
      export KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=#{protocol_map},CONTROLLER:PLAINTEXT
      export KAFKA_INTER_BROKER_LISTENER_NAME=BROKER
      export KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
      export KAFKA_CONTROLLER_QUORUM_VOTERS=1@$(hostname -i):9094
      sed -i '/KAFKA_ZOOKEEPER_CONNECT/d' /etc/confluent/docker/configure
      echo 'kafka-storage format --ignore-formatted -t "#{config.cluster_id}" -c /etc/kafka/kafka.properties' >> /etc/confluent/docker/configure
      """
    end

    # ----------------------- Default -----------------------
    defp init_script(container, config) do
      internal = "BROKER://$(hostname -i):#{config.broker_port}"

      external =
        "OUTSIDE://#{Testcontainers.get_host()}:#{Container.mapped_port(container, config.kafka_port)}"

      """
      export KAFKA_BROKER_ID=#{config.broker_id}
      export KAFKA_ADVERTISED_LISTENERS=#{internal},#{external}
      echo '' > /etc/confluent/docker/ensure
      """
    end

    defp add_run_command(script) do
      """
      #{script}
      /etc/confluent/docker/run
      echo finished
      """
    end

    defp parse_script(script) do
      script
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end
  end
end
