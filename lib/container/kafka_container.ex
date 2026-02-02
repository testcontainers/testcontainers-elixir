defmodule Testcontainers.KafkaContainer do
  @moduledoc """
  Provides functionality for creating and managing Kafka container configurations.

  This implementation uses the official `apache/kafka` Docker image which runs in KRaft mode
  by default (no Zookeeper required). This makes Kafka deployment significantly simpler.

  ## Example

      config = KafkaContainer.new()
      {:ok, container} = Testcontainers.start_container(config)

      # Get the bootstrap server address
      bootstrap_servers = KafkaContainer.bootstrap_servers(container)

  ## With automatic topic creation

      config =
        KafkaContainer.new()
        |> KafkaContainer.with_topics(["my-topic", "other-topic"])

      {:ok, container} = Testcontainers.start_container(config)

  ## Note on Port Binding

  This implementation uses a randomly selected fixed host port (between 29000-29999) for
  the Kafka listener. This is necessary because the apache/kafka image requires knowing
  the advertised listener address at startup time, before the container's dynamic port
  mapping is known.

  If you need to use a specific port, you can set it with `with_kafka_port/2`.
  """

  alias Testcontainers.Container
  alias Testcontainers.Docker
  alias Testcontainers.KafkaContainer
  alias Testcontainers.LogWaitStrategy

  @default_image "apache/kafka"
  @default_tag "3.9.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_internal_kafka_port 9092
  @default_controller_port 9093
  @default_node_id 1
  @default_wait_timeout 60_000
  @default_cluster_id "4L6g3nShT-eMCtK--X86sw"

  @enforce_keys [
    :image,
    :kafka_port,
    :internal_kafka_port,
    :controller_port,
    :node_id,
    :cluster_id,
    :wait_timeout
  ]
  defstruct [
    :image,
    :kafka_port,
    :internal_kafka_port,
    :controller_port,
    :node_id,
    :cluster_id,
    :wait_timeout,
    topics: [],
    reuse: false
  ]

  @doc """
  Creates a new `KafkaContainer` struct with default configurations.

  A random port between 29000-29999 is selected for the Kafka listener.
  """
  def new do
    # Select a random port in a high range to minimize conflicts
    kafka_port = Enum.random(29000..29999)

    %__MODULE__{
      image: @default_image_with_tag,
      kafka_port: kafka_port,
      internal_kafka_port: @default_internal_kafka_port,
      controller_port: @default_controller_port,
      node_id: @default_node_id,
      cluster_id: @default_cluster_id,
      wait_timeout: @default_wait_timeout,
      topics: []
    }
  end

  @doc """
  Overrides the default image used for the Kafka container.
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the host port used for the Kafka container.

  This port will be used on the host machine and also as the advertised listener port.
  """
  def with_kafka_port(%__MODULE__{} = config, kafka_port) when is_integer(kafka_port) do
    %{config | kafka_port: kafka_port}
  end

  @doc """
  Overrides the default controller port used for the Kafka container.
  """
  def with_controller_port(%__MODULE__{} = config, controller_port)
      when is_integer(controller_port) do
    %{config | controller_port: controller_port}
  end

  @doc """
  Overrides the default node id used for the Kafka container.
  """
  def with_node_id(%__MODULE__{} = config, node_id) when is_integer(node_id) do
    %{config | node_id: node_id}
  end

  @doc """
  Overrides the default cluster id used for the Kafka container.
  """
  def with_cluster_id(%__MODULE__{} = config, cluster_id) when is_binary(cluster_id) do
    %{config | cluster_id: cluster_id}
  end

  @doc """
  Overrides the default wait timeout used for the Kafka container.
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Sets the topics to be created automatically when the container starts.

  ## Example

      config =
        KafkaContainer.new()
        |> KafkaContainer.with_topics(["my-topic", "other-topic"])
  """
  def with_topics(%__MODULE__{} = config, topics) when is_list(topics) do
    %{config | topics: topics}
  end

  @doc """
  Set the reuse flag to reuse the container if it is already running.
  """
  def with_reuse(%__MODULE__{} = config, reuse) when is_boolean(reuse) do
    %__MODULE__{config | reuse: reuse}
  end

  @doc """
  Returns the bootstrap servers string for connecting to the Kafka container.
  """
  def bootstrap_servers(%Container{} = container) do
    port = Container.mapped_port(container, @default_internal_kafka_port)
    "#{Testcontainers.get_host()}:#{port}"
  end

  @doc """
  Returns the port on the host machine where the Kafka container is listening.
  """
  def port(%Container{} = container),
    do: Container.mapped_port(container, @default_internal_kafka_port)

  defimpl Testcontainers.ContainerBuilder do
    import Container

    @impl true
    @spec build(%KafkaContainer{}) :: %Container{}
    def build(%KafkaContainer{} = config) do
      host = Testcontainers.get_host()

      new(config.image)
      |> with_fixed_port(config.internal_kafka_port, config.kafka_port)
      |> with_kraft_config(config, host)
      |> with_reuse(config.reuse)
      |> with_waiting_strategy(
        LogWaitStrategy.new(
          ~r/Kafka Server started/,
          config.wait_timeout,
          1000
        )
      )
    end

    @doc """
    After the container starts, create any specified topics.
    """
    @impl true
    def after_start(config, container, conn) do
      # Create topics if specified
      Enum.each(config.topics, fn topic ->
        create_topic(container.container_id, conn, topic, config.internal_kafka_port)
      end)

      :ok
    end

    # KRaft mode environment configuration
    defp with_kraft_config(container, config, host) do
      container
      |> with_environment(:KAFKA_NODE_ID, "#{config.node_id}")
      |> with_environment(:KAFKA_PROCESS_ROLES, "broker,controller")
      |> with_environment(:KAFKA_CONTROLLER_LISTENER_NAMES, "CONTROLLER")
      |> with_environment(:KAFKA_INTER_BROKER_LISTENER_NAME, "PLAINTEXT")
      |> with_environment(
        :KAFKA_LISTENERS,
        "PLAINTEXT://:#{config.internal_kafka_port},CONTROLLER://:#{config.controller_port}"
      )
      |> with_environment(
        :KAFKA_LISTENER_SECURITY_PROTOCOL_MAP,
        "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
      )
      |> with_environment(
        :KAFKA_CONTROLLER_QUORUM_VOTERS,
        "#{config.node_id}@localhost:#{config.controller_port}"
      )
      |> with_environment(
        :KAFKA_ADVERTISED_LISTENERS,
        "PLAINTEXT://#{host}:#{config.kafka_port}"
      )
      |> with_environment(:KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR, "1")
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR, "1")
      |> with_environment(:KAFKA_TRANSACTION_STATE_LOG_MIN_ISR, "1")
      |> with_environment(:KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS, "0")
    end

    defp create_topic(container_id, conn, topic, kafka_port) do
      cmd = [
        "/opt/kafka/bin/kafka-topics.sh",
        "--bootstrap-server",
        "localhost:#{kafka_port}",
        "--create",
        "--topic",
        topic,
        "--partitions",
        "1",
        "--replication-factor",
        "1",
        "--if-not-exists"
      ]

      result =
        case Docker.Api.start_exec(container_id, cmd, conn) do
          {:ok, exec_id} ->
            wait_for_exec(exec_id, conn)

          {:error, reason} ->
            {:error, reason}
        end

      # Wait for leader election to complete
      Process.sleep(2000)
      result
    end

    defp wait_for_exec(exec_id, conn) do
      case Docker.Api.inspect_exec(exec_id, conn) do
        {:ok, %{running: true}} ->
          Process.sleep(100)
          wait_for_exec(exec_id, conn)

        {:ok, %{running: false, exit_code: 0}} ->
          :ok

        {:ok, %{running: false, exit_code: code}} ->
          {:error, {:exec_failed, code}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
