defmodule Testcontainers.Container.KafkaContainerTest do
  use ExUnit.Case, async: false
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.KafkaContainer

  @moduletag timeout: 200_000

  describe "new/0" do
    test "creates a new KafkaContainer struct with default configurations" do
      config = KafkaContainer.new()

      assert config.image == "apache/kafka:3.9.0"
      assert config.kafka_port >= 29000 and config.kafka_port <= 29999
      assert config.internal_kafka_port == 9092
      assert config.controller_port == 9093
      assert config.node_id == 1
      assert config.wait_timeout == 60_000
      assert config.cluster_id == "4L6g3nShT-eMCtK--X86sw"
      assert config.topics == []
    end
  end

  describe "with_image/2" do
    test "overrides the default image used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_image(config, "apache/kafka:3.8.0")

      assert new_config.image == "apache/kafka:3.8.0"
    end

    test "raises if the image is not a binary" do
      config = KafkaContainer.new()
      assert_raise FunctionClauseError, fn -> KafkaContainer.with_image(config, 6.2) end
    end
  end

  describe "with_kafka_port/2" do
    test "overrides the default kafka port used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_kafka_port(config, 9094)

      assert new_config.kafka_port == 9094
    end

    test "raises if the kafka port is not an integer" do
      config = KafkaContainer.new()
      assert_raise FunctionClauseError, fn -> KafkaContainer.with_kafka_port(config, "9094") end
    end
  end

  describe "with_controller_port/2" do
    test "overrides the default controller port used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_controller_port(config, 9095)

      assert new_config.controller_port == 9095
    end

    test "raises if the controller port is not an integer" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_controller_port(config, "9095")
      end
    end
  end

  describe "with_node_id/2" do
    test "overrides the default node id used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_node_id(config, 2)

      assert new_config.node_id == 2
    end

    test "raises if the node id is not integer" do
      config = KafkaContainer.new()
      assert_raise FunctionClauseError, fn -> KafkaContainer.with_node_id(config, "2") end
    end
  end

  describe "with_cluster_id/2" do
    test "overrides the default cluster_id used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_cluster_id(config, "1234")

      assert new_config.cluster_id == "1234"
    end

    test "raises if the cluster_id is not a binary" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_cluster_id(config, 123)
      end
    end
  end

  describe "with_wait_timeout/2" do
    test "overrides the default wait timeout used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_wait_timeout(config, 60_001)

      assert new_config.wait_timeout == 60_001
    end

    test "raises if the wait timeout is not an integer" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_wait_timeout(config, "60_001")
      end
    end
  end

  describe "with_topics/2" do
    test "sets the topics to be created automatically" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_topics(config, ["topic1", "topic2"])

      assert new_config.topics == ["topic1", "topic2"]
    end

    test "raises if topics is not a list" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_topics(config, "topic1")
      end
    end
  end

  describe "kafka container" do
    container(:kafka, KafkaContainer.new())

    test "provides a ready-to-use kafka container", %{kafka: kafka} do
      worker_name = :worker
      topic_name = "test_topic"
      uris = [{"localhost", Container.mapped_port(kafka, 9092)}]

      {:ok, pid} = KafkaEx.create_worker(:worker, uris: uris, consumer_group: "kafka_ex")
      on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)

      :ok = create_topic(worker_name, topic_name, [])

      {:ok, _} = KafkaEx.produce(topic_name, 0, "hey", worker_name: worker_name, required_acks: 1)
      stream = KafkaEx.stream(topic_name, 0, worker_name: :worker)
      [response] = Enum.take(stream, 1)

      assert response.value == "hey"
    end
  end

  describe "kafka container with automatic topic creation" do
    container(:kafka, KafkaContainer.new() |> KafkaContainer.with_topics(["auto_topic"]))

    test "creates topics automatically", %{kafka: kafka} do
      worker_name = :auto_worker
      topic_name = "auto_topic"
      uris = [{"localhost", Container.mapped_port(kafka, 9092)}]

      {:ok, pid} = KafkaEx.create_worker(worker_name, uris: uris, consumer_group: "kafka_ex")
      on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)

      # Topic should already exist - refresh metadata and wait for leader
      :timer.sleep(1000)
      KafkaEx.metadata(worker_name: worker_name)
      :timer.sleep(1000)

      # Try produce with retries for leader election
      {:ok, _} = produce_with_retry(topic_name, "auto_message", worker_name, 5)

      stream = KafkaEx.stream(topic_name, 0, worker_name: worker_name)
      [response] = Enum.take(stream, 1)

      assert response.value == "auto_message"
    end
  end

  describe "helper functions" do
    container(:kafka, KafkaContainer.new())

    test "bootstrap_servers returns the correct connection string", %{kafka: kafka} do
      bootstrap = KafkaContainer.bootstrap_servers(kafka)
      assert bootstrap =~ ~r/^localhost:\d+$/
    end

    test "port returns the mapped port", %{kafka: kafka} do
      port = KafkaContainer.port(kafka)
      assert is_integer(port)
      assert port > 0
    end
  end

  # After creating a topic, we need to wait for a short period of time for the topic to be created and
  # available for use.
  defp create_topic(worker_name, topic_name, opts) do
    request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
      topic: topic_name,
      num_partitions: Keyword.get(opts, :num_partitions, 1),
      replication_factor: Keyword.get(opts, :replication_factor, 1),
      replica_assignment: Keyword.get(opts, :replica_assignment, [])
    }

    KafkaEx.create_topics([request], worker_name: worker_name)
    :timer.sleep(100)

    :ok
  end

  # Retry producing a message if leader is not available yet
  defp produce_with_retry(topic_name, message, worker_name, retries) when retries > 0 do
    case KafkaEx.produce(topic_name, 0, message, worker_name: worker_name, required_acks: 1) do
      {:ok, _} = result ->
        result

      :leader_not_available ->
        :timer.sleep(1000)
        produce_with_retry(topic_name, message, worker_name, retries - 1)

      error ->
        error
    end
  end

  defp produce_with_retry(_topic_name, _message, _worker_name, 0) do
    {:error, :leader_not_available_after_retries}
  end
end
