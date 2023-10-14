# SPDX-License-Identifier: MIT
defmodule TestcontainersElixir.Container.CephContainer do
  alias TestcontainersElixir.WaitStrategy.LogWaitStrategy
  alias TestcontainersElixir.Container

  @waiting_strategy LogWaitStrategy.new(
                      ~r/.*Bucket 's3:\/\/.*\/' created.*/,
                      300_000
                    )

  def new(options \\ []) do
    image = Keyword.get(options, :image, "quay.io/ceph/demo:latest-quincy")
    access_key = Keyword.get(options, :access_key, "demo")
    secret_key = Keyword.get(options, :secret_key, "demo")
    bucket = Keyword.get(options, :bucket, "demo")

    Container.new(image,
      exposed_ports: [3300, 8080],
      environment: %{
        CEPH_DEMO_UID: "demo",
        CEPH_DEMO_BUCKET: "#{bucket}",
        CEPH_DEMO_ACCESS_KEY: "#{access_key}",
        CEPH_DEMO_SECRET_KEY: "#{secret_key}",
        CEPH_PUBLIC_NETWORK: "0.0.0.0/0",
        MON_IP: "127.0.0.1",
        RGW_NAME: "localhost"
      },
      waiting_strategy: @waiting_strategy
    )
  end
end
