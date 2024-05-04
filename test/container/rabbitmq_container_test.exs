defmodule Testcontainers.Container.RabbitMQContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.RabbitMQContainer

  @moduletag timeout: 300_000

  describe "with default configuration" do
    container(:rabbitmq, RabbitMQContainer.new())

    test "provides a ready-to-use rabbitmq container by using connection parameters", %{
      rabbitmq: rabbitmq
    } do
      {:ok, connection} =
        RabbitMQContainer.connection_parameters(rabbitmq)
        |> AMQP.Connection.open()

      do_assertion(connection)
    end

    test "provides a ready-to-use rabbitmq container by using connection URL", %{
      rabbitmq: rabbitmq
    } do
      {:ok, connection} =
        RabbitMQContainer.connection_url(rabbitmq)
        |> AMQP.Connection.open()

      do_assertion(connection)
    end
  end

  describe "with custom configuration" do
    @custom_rabbitmq RabbitMQContainer.new()
                     |> RabbitMQContainer.with_image("rabbitmq:3-management-alpine")
                     |> RabbitMQContainer.with_port(5671)
                     |> RabbitMQContainer.with_username("custom-user")
                     |> RabbitMQContainer.with_password("custom_password")
                     |> RabbitMQContainer.with_virtual_host("custom-virtual-host")

    container(:rabbitmq, @custom_rabbitmq)

    test "provides a rabbitmq container compliant with specified configuration", %{
      rabbitmq: rabbitmq
    } do
      {:ok, connection} =
        RabbitMQContainer.connection_parameters(rabbitmq)
        |> AMQP.Connection.open()

      do_assertion(connection)
    end
  end

  defp do_assertion(connection) do
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, "channel")
    AMQP.Basic.publish(channel, "", "channel", "Hello")
    AMQP.Basic.consume(channel, "channel", nil, no_ack: true)

    assert_receive {:basic_consume_ok, %{consumer_tag: _consumer_tag}}
    assert_receive {:basic_deliver, "Hello", _meta}
    AMQP.Connection.close(connection)
  end
end
