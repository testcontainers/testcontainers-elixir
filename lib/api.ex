# SPDX-License-Identifier: MIT
defmodule TestcontainersElixir.Docker.Api do
  alias TestcontainersElixir.WaitStrategy
  alias DockerEngineAPI.Model.ContainerCreateRequest
  alias DockerEngineAPI.Model.ContainerCreateResponse
  alias DockerEngineAPI.Api
  alias TestcontainersElixir.Container
  alias TestcontainersElixir.Reaper
  alias TestcontainersElixir.Connection

  def run(%Container{} = container_config, options \\ [], conn \\ Connection.get_connection()) do
    on_exit = Keyword.get(options, :on_exit, nil)
    wait_strategy = container_config.waiting_strategy
    create_request = container_create_request(container_config)

    with {:ok, _} <- Api.Image.image_create(conn, fromImage: create_request."Image"),
         {:ok, %ContainerCreateResponse{Id: container_id}} <-
           Api.Container.container_create(conn, create_request),
         {:ok, _} <- Api.Container.container_start(conn, container_id),
         :ok <-
           (if on_exit do
              with :ok <- on_exit.(:stop_container, fn -> stop_container(conn, container_id) end) do
                reap_container(container_id)
              end
            else
              :ok
            end),
         {:ok, container} <- get_container(container_id, conn),
         :ok <-
           if(wait_strategy != nil,
             do:
               WaitStrategy.wait_until_container_is_ready(wait_strategy, container.container_id),
             else: :ok
           ) do
      {:ok, container}
    end
  end

  def stdout_logs(container_id, conn \\ Connection.get_connection()) do
    Api.Container.container_logs(conn, container_id, stdout: true)
  end

  def execute_cmd(container_id, cmd, conn \\ Connection.get_connection()) when is_list(cmd) do
    with {:ok, %DockerEngineAPI.Model.IdResponse{Id: container_id}} <-
           Api.Exec.container_exec(conn, container_id, %DockerEngineAPI.Model.ExecConfig{Cmd: cmd}) do
      {:ok, container_id}
    end
  end

  def get_container(container_id, conn \\ Connection.get_connection())
      when is_binary(container_id) do
    with {:ok, response} <- Api.Container.container_inspect(conn, container_id) do
      {:ok, from(response)}
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

  defp stop_container(conn, container_id) when is_binary(container_id) do
    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  defp reap_container(container_id) when is_binary(container_id) do
    case Reaper.start_link() do
      {:error, {:already_started, _}} -> :ok
      {:ok, _} -> :ok
    end

    Reaper.register({"id", container_id})
  end

  defp from(%DockerEngineAPI.Model.ContainerInspectResponse{
         Id: container_id,
         Image: image,
         NetworkSettings: %{Ports: ports}
       }) do
    ports =
      Enum.reduce(ports || [], [], fn {key, ports}, acc ->
        acc ++
          Enum.map(ports || [], fn %{"HostIp" => host_ip, "HostPort" => host_port} ->
            %{exposed_port: key, host_ip: host_ip, host_port: host_port |> String.to_integer()}
          end)
      end)

    %Container{container_id: container_id, image: image, exposed_ports: ports}
  end
end
