# SPDX-License-Identifier: MIT
defmodule Testcontainers.Docker.Api do
  alias Testcontainers.WaitStrategy
  alias DockerEngineAPI.Model.ContainerCreateRequest
  alias DockerEngineAPI.Api
  alias Testcontainers.Container
  alias Testcontainers.ReaperWorker
  alias Testcontainers.Docker.Connection

  def run(%Container{} = container_config, options \\ []) do
    on_exit = Keyword.get(options, :on_exit, nil)
    wait_strategies = container_config.wait_strategies || []
    create_request = container_create_request(container_config)

    with :ok <- pull_image(create_request."Image", recv_timeout: 60_000),
         {:ok, id} <- create_container(create_request, recv_timeout: 2000),
         :ok <- start_container(id, recv_timeout: 300_000),
         :ok <- if(on_exit, do: on_exit.(fn -> stop_container(id) end), else: :ok),
         :ok <- reap_container(id),
         :ok <- wait_for_container(id, wait_strategies) do
      get_container(id)
    end
  end

  def get_container(container_id, options \\ [])
      when is_binary(container_id) do
    conn = Connection.get_connection(options)

    case Api.Container.container_inspect(conn, container_id) do
      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_get_container, error}}

      {:ok, response} ->
        {:ok, from(response)}
    end
  end

  defp wait_for_container(id, wait_strategies) when is_binary(id) do
    Enum.reduce(wait_strategies, :ok, fn
      wait_strategy, :ok ->
        WaitStrategy.wait_until_container_is_ready(wait_strategy, id)

      _, error ->
        error
    end)
  end

  defp pull_image(image, options) when is_binary(image) do
    conn = Connection.get_connection(options)

    case Api.Image.image_create(conn, fromImage: image) do
      {:ok, %Tesla.Env{status: 200}} ->
        :ok

      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_pull_image, error}}
    end
  end

  defp create_container(%ContainerCreateRequest{} = config, options) do
    conn = Connection.get_connection(options)

    case Api.Container.container_create(conn, config) do
      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %{Id: id}} ->
        {:ok, id}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_create_container, error}}
    end
  end

  defp start_container(id, options) when is_binary(id) do
    conn = Connection.get_connection(options)

    case Api.Container.container_start(conn, id) do
      {:ok, %Tesla.Env{status: 204}} ->
        :ok

      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_start_container, error}}
    end
  end

  defp container_create_request(%Container{} = container_config) do
    %ContainerCreateRequest{
      Image: container_config.image,
      Cmd: container_config.cmd,
      ExposedPorts: map_exposed_ports(container_config),
      Env: map_env(container_config),
      Labels: container_config.labels,
      HostConfig: %{
        AutoRemove: container_config.auto_remove,
        PortBindings: map_port_bindings(container_config),
        Privileged: container_config.privileged,
        Binds: map_binds(container_config)
      }
    }
  end

  defp map_exposed_ports(%Container{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, _host_port} -> {container_port, %{}}
      port -> {port, %{}}
    end)
    |> Enum.into(%{})
  end

  defp map_env(%Container{} = container_config) do
    container_config.environment
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
  end

  defp map_port_bindings(%Container{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, host_port} ->
        {container_port, [%{"HostIp" => "0.0.0.0", "HostPort" => to_string(host_port)}]}

      port ->
        {port, [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]}
    end)
    |> Enum.into(%{})
  end

  defp map_binds(%Container{} = container_config) do
    container_config.bind_mounts
    |> Enum.map(fn volume_binding ->
      "#{volume_binding.host_src}:#{volume_binding.container_dest}:#{volume_binding.options}"
    end)
  end

  defp stop_container(container_id, options \\ []) when is_binary(container_id) do
    conn = Connection.get_connection(options)

    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  defp reap_container(container_id) when is_binary(container_id) do
    ReaperWorker.register({"id", container_id})
  end

  defp from(
         %DockerEngineAPI.Model.ContainerInspectResponse{
           Id: container_id,
           Image: image,
           NetworkSettings: %{Ports: ports}
         } = res
       ) do
    ports =
      Enum.reduce(ports || [], [], fn {key, ports}, acc ->
        acc ++
          Enum.map(ports || [], fn %{"HostIp" => host_ip, "HostPort" => host_port} ->
            %{exposed_port: key, host_ip: host_ip, host_port: host_port |> String.to_integer()}
          end)
      end)

    environment =
      Enum.reduce(res."Config"."Env" || [], %{}, fn env, acc ->
        tokens = String.split(env, "=")
        Map.merge(acc, %{"#{List.first(tokens)}": List.last(tokens)})
      end)

    %Container{
      container_id: container_id,
      image: image,
      exposed_ports: ports,
      environment: environment
    }
  end
end
