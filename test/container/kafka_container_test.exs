defmodule Testcontainers.Container.KafkaContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.KafkaContainer
  alias Test.ZookeeperContainer

  @moduletag timeout: 200_000

  describe "new/0" do
    test "creates a new KafkaContainer struct with default configurations" do
      config = KafkaContainer.new()

      assert config.image == "confluentinc/cp-kafka:7.4.3"
      assert config.kafka_port == 9092
      assert config.broker_port == 29092
      assert config.zookeeper_port == 2181
      assert config.wait_timeout == 60_000
      assert config.consensus_strategy == :zookeeper_embedded
      assert config.cluster_id == "4L6g3nShT-eMCtK--X86sw"
      assert config.zookeeper_host == nil
      assert config.default_topic_partitions == 1
    end
  end

  describe "with_image/2" do
    test "overrides the default image used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_image(config, "confluentinc/cp-kafka:6.2.0")

      assert new_config.image == "confluentinc/cp-kafka:6.2.0"
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

  describe "with_broker_port/2" do
    test "overrides the default broker port used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_broker_port(config, 9095)

      assert new_config.broker_port == 9095
    end

    test "raises if the broker port is not an integer" do
      config = KafkaContainer.new()
      assert_raise FunctionClauseError, fn -> KafkaContainer.with_broker_port(config, "9095") end
    end
  end

  describe "with_zookeeper_port/2" do
    test "overrides the default zookeeper port used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_zookeeper_port(config, 2182)

      assert new_config.zookeeper_port == 2182
    end

    test "raises if the zookeeper port is not an integer" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:zookeeper_embedded)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_zookeeper_port(config, "2182")
      end
    end

    test "raises if consensus strategy is not zookeeper" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:kraft)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_zookeeper_port(config, 2182)
      end
    end
  end

  describe "with_zookeeper_host/2" do
    test "overrides the default zookeeper host used for the Kafka container" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:zookeeper_external)
      new_config = KafkaContainer.with_zookeeper_host(config, "localhost")

      assert new_config.zookeeper_host == "localhost"
    end

    test "raises if the zookeeper host is not an binary" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:zookeeper_external)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_zookeeper_host(config, 123)
      end
    end

    test "raises if the zookeeper strategy is not an external" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:zookeeper_embedded)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_zookeeper_host(config, "localhost")
      end
    end
  end

  describe "with_cluster_id/2" do
    test "overrides the default cluster_id used for the Kafka container" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:kraft)
      new_config = KafkaContainer.with_cluster_id(config, "1234")

      assert new_config.cluster_id == "1234"
    end

    test "raises if the cluster_id is not an binary" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:kraft)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_cluster_id(config, 123)
      end
    end

    test "raises if the consensus strategy is not an kraft" do
      config = KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:zookeeper_embedded)

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_cluster_id(config, "localhost")
      end
    end
  end

  describe "with_consensus_strategy/2" do
    test "overrides the consensus strategy host used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_consensus_strategy(config, :zookeeper_external)

      assert new_config.consensus_strategy == :zookeeper_external
    end

    test "raises if the zookeeper strategy is invalid" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_consensus_strategy(config, :host)
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

  describe "with_topic_partitions/2" do
    test "overrides the default topic partitions used for the Kafka container" do
      config = KafkaContainer.new()
      new_config = KafkaContainer.with_topic_partitions(config, 2)

      assert new_config.default_topic_partitions == 2
    end

    test "raises if the topic partitions is not an integer" do
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_topic_partitions(config, "2")
      end
    end
  end

  describe "with internal zookeeper" do
    container(:kafka, KafkaContainer.new())

    test "provides a ready-to-use kafka container", %{kafka: kafka} do
      uris = [{"localhost", Container.mapped_port(kafka, 9092) || 9092}]

      {:ok, pid} = KafkaEx.create_worker(:worker, uris: uris, consumer_group: "kafka_ex")
      on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)

      request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
        topic: "test_topic",
        num_partitions: 1,
        replication_factor: 1,
        replica_assignment: []
      }

      _ = KafkaEx.create_topics([request], worker_name: :worker)
      {:ok, _} = KafkaEx.produce("test_topic", 0, "hey", worker_name: :worker, required_acks: 1)
      stream = KafkaEx.stream("test_topic", 0, worker_name: :worker)
      [response] = Enum.take(stream, 1)

      assert response.value == "hey"
    end
  end

  describe "with external zookeeper" do
    test "provides a ready-to-use kafka container" do
      {:ok, kafka} = start_kafka_with_external_zookeeper()
      uris = [{"localhost", Container.mapped_port(kafka, 9092) || 9092}]

      {:ok, pid} = KafkaEx.create_worker(:worker, uris: uris, consumer_group: "kafka_ex")
      on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)

      request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
        topic: "test_topic",
        num_partitions: 1,
        replication_factor: 1,
        replica_assignment: []
      }

      _ = KafkaEx.create_topics([request], worker_name: :worker)
      {:ok, _} = KafkaEx.produce("test_topic", 0, "hey", worker_name: :worker, required_acks: 1)
      stream = KafkaEx.stream("test_topic", 0, worker_name: :worker)
      [response] = Enum.take(stream, 1)

      assert response.value == "hey"
    end
  end

  describe "with raft mode" do
    container(:kafka, KafkaContainer.new() |> KafkaContainer.with_consensus_strategy(:kraft))

    test "provides a ready-to-use kafka container", %{kafka: kafka} do
      uris = [{"localhost", Container.mapped_port(kafka, 9092) || 9092}]

      {:ok, pid} = KafkaEx.create_worker(:worker, uris: uris, consumer_group: "kafka_ex")
      on_exit(fn -> :ok = KafkaEx.stop_worker(pid) end)

      request = %KafkaEx.Protocol.CreateTopics.TopicRequest{
        topic: "test_topic",
        num_partitions: 1,
        replication_factor: 1,
        replica_assignment: []
      }

      _ = KafkaEx.create_topics([request], worker_name: :worker)
      {:ok, _} = KafkaEx.produce("test_topic", 0, "hey", worker_name: :worker, required_acks: 1)
      stream = KafkaEx.stream("test_topic", 0, worker_name: :worker)
      [response] = Enum.take(stream, 1)

      assert response.value == "hey"
    end
  end

  defp start_kafka_with_external_zookeeper do
    {:ok, zookeeper} = Testcontainers.start_container(%ZookeeperContainer{})
    on_exit(fn -> Testcontainers.stop_container(zookeeper.container_id) end)

    {:ok, kafka} =
      Testcontainers.start_container(
        KafkaContainer.new()
        |> KafkaContainer.with_consensus_strategy(:zookeeper_external)
        |> KafkaContainer.with_zookeeper_host(zookeeper.ip_address)
      )

    on_exit(fn -> Testcontainers.stop_container(kafka.container_id) end)

    {:ok, kafka}
  end
end
