# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.CephContainer do
  alias TestcontainersElixir.LogChecker
  alias DockerEngineAPI.Model

  def create_container(options \\ []) do
    image = Keyword.get(options, :image, "quay.io/ceph/demo:latest-quincy")
    access_key = Keyword.get(options, :access_key, "demo")
    secret_key = Keyword.get(options, :secret_key, "demo")
    bucket = Keyword.get(options, :bucket, "demo")

    %Model.ContainerCreateRequest{
      Image: image,
      ExposedPorts: %{"3300" => %{}, "8080" => %{}},
      HostConfig: %{
        PortBindings: %{
          "3300" => [%{"HostIp" => "0.0.0.0", "HostPort" => ""}],
          "8080" => [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]
        }
      },
      Env: [
        "CEPH_DEMO_UID=demo",
        "CEPH_DEMO_BUCKET=#{bucket}",
        "CEPH_DEMO_ACCESS_KEY=#{access_key}",
        "CEPH_DEMO_SECRET_KEY=#{secret_key}",
        "CEPH_PUBLIC_NETWORK=0.0.0.0/0",
        "MON_IP=127.0.0.1",
        "RGW_NAME=localhost"
      ]
    }
  end

  def waiting_strategy(conn, container),
    do:
      LogChecker.wait_for_log(
        conn,
        container.container_id,
        ~r/.*Bucket 's3:\/\/.*\/' created.*/,
        300_000
      )
end
