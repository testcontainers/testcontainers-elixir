# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.CephContainer do
  alias Testcontainers.WaitStrategy.HttpWaitStrategy
  alias Testcontainers.WaitStrategy.LogWaitStrategy
  alias Testcontainers.Container

  def new(options \\ []) do
    image = Keyword.get(options, :image, "quay.io/ceph/demo:latest-quincy")
    access_key = Keyword.get(options, :access_key, "demo")
    secret_key = Keyword.get(options, :secret_key, "demo")
    bucket = Keyword.get(options, :bucket, "demo")

    Container.new(image,
      exposed_ports: [3300, 8080],
      environment: %{
        CEPH_DEMO_UID: "demo",
        CEPH_DEMO_BUCKET: bucket,
        CEPH_DEMO_ACCESS_KEY: access_key,
        CEPH_DEMO_SECRET_KEY: secret_key,
        CEPH_PUBLIC_NETWORK: "0.0.0.0/0",
        MON_IP: "127.0.0.1",
        RGW_NAME: "localhost"
      }
    )
    |> Container.with_waiting_strategies(wait_strategies(8080, bucket))
  end

  def with_bucket(%Container{} = container, bucket) when is_binary(bucket) do
    %{container | environment: Map.put(container.environment, :CEPH_DEMO_BUCKET, bucket)}
  end

  def with_access_key(%Container{} = container, access_key) when is_binary(access_key) do
    %{container | environment: Map.put(container.environment, :CEPH_DEMO_ACCESS_KEY, access_key)}
  end

  def with_secret_key(%Container{} = container, secret_key) when is_binary(secret_key) do
    %{container | environment: Map.put(container.environment, :CEPH_DEMO_SECRET_KEY, secret_key)}
  end

  defp wait_strategies(port, bucket) do
    [
      LogWaitStrategy.new(
        ~r/.*Bucket 's3:\/\/#{bucket}\/' created.*/,
        300_000,
        5000
      ),
      HttpWaitStrategy.new("127.0.0.1", port, "/")
    ]
  end
end
