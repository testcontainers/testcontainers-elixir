# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MongoContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.CommandWaitStrategy
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.MongoContainer

  describe "new/0 and builder options" do
    test "returns default mongo configuration" do
      config = MongoContainer.new()

      assert config.image == "mongo:latest"
      assert config.user == "test"
      assert config.password == "test"
      assert config.database == "test"
      assert config.port == 27_017
      assert config.wait_timeout == 180_000
    end

    test "supports custom image" do
      config = MongoContainer.new() |> MongoContainer.with_image("bitnami/mongodb:latest")
      assert config.image == "bitnami/mongodb:latest"
    end

    test "with_username/2 delegates to with_user/2" do
      config = MongoContainer.new() |> MongoContainer.with_username("foo")
      assert config.user == "foo"
    end

    test "sets Mongo init env vars and a Mongo readiness command" do
      container =
        MongoContainer.new()
        |> MongoContainer.with_user("mongo-user")
        |> MongoContainer.with_password("mongo-pass")
        |> MongoContainer.with_database("mongo-db")
        |> ContainerBuilder.build()

      assert container.environment[:MONGO_INITDB_ROOT_USERNAME] == "mongo-user"
      assert container.environment[:MONGO_INITDB_ROOT_PASSWORD] == "mongo-pass"
      assert container.environment[:MONGO_INITDB_DATABASE] == "mongo-db"

      assert [%CommandWaitStrategy{command: ["sh", "-c", command]}] = container.wait_strategies
      assert command =~ "db.adminCommand('ping')"
    end

    test "mounts persistent volume in Mongo data path" do
      container =
        MongoContainer.new()
        |> MongoContainer.with_persistent_volume("mongo_data")
        |> ContainerBuilder.build()

      assert [%{volume: "mongo_data", container_dest: "/data/db", read_only: false}] =
               container.bind_volumes
    end
  end

  describe "runtime behavior" do
    container(:mongo, MongoContainer.new())

    test "has the default port mapped", %{mongo: mongo} do
      assert MongoContainer.port(mongo)
    end

    test "returns connection parameters", %{mongo: mongo} do
      params = MongoContainer.connection_parameters(mongo)
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert params[:hostname] == host
      assert params[:port] == port
      assert params[:username] == "test"
      assert params[:password] == "test"
      assert params[:database] == "test"
    end

    test "returns default database urls", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)
      assert MongoContainer.mongo_url(mongo) == "mongodb://test:test@#{host}:#{port}/test"
      assert MongoContainer.database_url(mongo) == "mongodb://test:test@#{host}:#{port}/test"
    end

    test "returns mongo url with custom database", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert MongoContainer.mongo_url(mongo, database: "foo") ==
               "mongodb://test:test@#{host}:#{port}/foo"
    end

    test "returns mongo url with custom protocol", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert MongoContainer.mongo_url(mongo, protocol: "mongodb2") ==
               "mongodb2://test:test@#{host}:#{port}/test"
    end

    test "returns mongo url with custom username", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert MongoContainer.mongo_url(mongo, username: "foo") ==
               "mongodb://foo:test@#{host}:#{port}/test"
    end

    test "returns mongo url with custom password", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert MongoContainer.mongo_url(mongo, password: "bar") ==
               "mongodb://test:bar@#{host}:#{port}/test"
    end

    test "returns mongo url with custom query options", %{mongo: mongo} do
      host = Testcontainers.get_host(mongo)
      port = MongoContainer.port(mongo)

      assert MongoContainer.mongo_url(mongo, options: [replicaSet: "rs0"]) ==
               "mongodb://test:test@#{host}:#{port}/test?replicaSet=rs0"
    end

    test "is reachable and can insert/query a document", %{mongo: mongo} do
      connection_params = MongoContainer.connection_parameters(mongo) ++ [auth_source: "admin"]
      {:ok, pid} = Mongo.start_link(connection_params)

      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      assert {:ok, %{inserted_id: _id}} =
               Mongo.insert_one(pid, "artists", %{name: "FKA Twigs"})

      artists =
        pid
        |> Mongo.find("artists", %{name: "FKA Twigs"})
        |> Enum.to_list()

      assert length(artists) == 1
    end
  end
end
