defmodule Testcontainers.Container.KafkaContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Container.KafkaContainer

  describe "new/0" do
    test "creates a new KafkaContainer struct with default configurations" do
      config = KafkaContainer.new()

      assert config.image == "confluentinc/cp-kafka:6.1.9"
      assert config.kafka_port == 9092
      assert config.broker_port == 9093
      assert config.zookeeper_port == 2181
      assert config.wait_timeout == 60_000
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

    test "raises if the image is not a confluentinc image" do
      config = KafkaContainer.new()
      assert_raise FunctionClauseError, fn -> KafkaContainer.with_image(config, "kafka:6.2.0") end
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
      config = KafkaContainer.new()

      assert_raise FunctionClauseError, fn ->
        KafkaContainer.with_zookeeper_port(config, "2182")
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
end
