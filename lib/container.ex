# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.Container do
  alias DockerEngineAPI.Api
  alias DockerEngineAPI.Connection
  alias DockerEngineAPI.Model.ContainerCreateRequest
  alias DockerEngineAPI.Model.ContainerCreateResponse
  alias TestcontainersElixir.Reaper
  alias TestcontainersElixir.Connection

  @enforce_keys [:image]

  defstruct [
    :image,
    cmd: nil,
    environment: %{},
    exposed_ports: [],
    privileged: false,
    bind_mounts: [],
    labels: %{},
    auto_remove: true,
    container_id: nil
  ]

  def new(image, opts \\ []) do
    %__MODULE__{
      image: image,
      bind_mounts: opts[:bind_mounts] || [],
      cmd: opts[:cmd],
      environment: opts[:environment] || %{},
      exposed_ports: Keyword.get(opts, :exposed_ports, []),
      privileged: opts[:privileged] || false,
      auto_remove: opts[:auto_remove] || true
    }
  end

  def with_environment(config, key, value) do
    %__MODULE__{config | environment: Map.put(config.environment, key, value)}
  end

  def with_exposed_port(config, port) do
    %__MODULE__{config | exposed_ports: [port | config.exposed_ports]}
  end

  def with_bind_mount(config, host_src, container_dest, options \\ "ro") do
    new_bind_mount = %{host_src: host_src, container_dest: container_dest, options: options}
    %__MODULE__{config | bind_mounts: [new_bind_mount | config.bind_mounts]}
  end

  def with_label(config, key, value) do
    %__MODULE__{config | labels: Map.put(config.labels, key, value)}
  end

  def from(%DockerEngineAPI.Model.ContainerInspectResponse{
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

    %__MODULE__{container_id: container_id, image: image, exposed_ports: ports}
  end

  def mapped_port(%__MODULE__{} = container, port) when is_number(port) do
    container.exposed_ports
    |> Enum.filter(fn
      %{exposed_port: exposed_port} -> exposed_port == "#{port}/tcp"
      port -> port == "#{port}/tcp"
    end)
    |> List.first(%{})
    |> Map.get(:host_port)
  end

  def run(%__MODULE__{} = container_config, options \\ []) do
    conn = Connection.get_connection()
    on_exit = Keyword.get(options, :on_exit, fn _, _ -> :ok end)
    waiting_strategy = Keyword.get(options, :waiting_strategy, nil)
    create_request = container_create_request(container_config)

    with {:ok, _} <- Api.Image.image_create(conn, fromImage: create_request."Image"),
         {:ok, %ContainerCreateResponse{Id: container_id}} <-
           Api.Container.container_create(conn, create_request),
         {:ok, _} <- Api.Container.container_start(conn, container_id),
         :ok <- on_exit.(:stop_container, fn -> stop_container(conn, container_id) end),
         :ok <- reap_container(container_id),
         {:ok, container} <- get_container(conn, container_id),
         {:ok, _} <-
           (if waiting_strategy != nil do
              waiting_strategy.(conn, container)
            else
              {:ok, nil}
            end) do
      {:ok, container}
    end
  end

  defp stop_container(conn, container_id) when is_binary(container_id) do
    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  defp get_container(conn, container_id) when is_binary(container_id) do
    with {:ok, response} <- Api.Container.container_inspect(conn, container_id) do
      {:ok, from(response)}
    end
  end

  defp reap_container(container_id) when is_binary(container_id) do
    case Reaper.start_link() do
      {:error, {:already_started, _}} -> :ok
      {:ok, _} -> :ok
    end

    Reaper.register({"id", container_id})
  end

  defp container_create_request(%__MODULE__{} = container_config) do
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

  defp map_exposed_ports(%__MODULE__{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, _host_port} -> {container_port, %{}}
      port -> {port, %{}}
    end)
    |> Enum.into(%{})
  end

  defp map_env(%__MODULE__{} = container_config) do
    container_config.environment
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
  end

  defp map_port_bindings(%__MODULE__{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, host_port} ->
        {container_port, [%{"HostIp" => "0.0.0.0", "HostPort" => to_string(host_port)}]}

      port ->
        {port, [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]}
    end)
    |> Enum.into(%{})
  end

  defp map_binds(%__MODULE__{} = container_config) do
    container_config.bind_mounts
    |> Enum.map(fn volume_binding ->
      "#{volume_binding.host_src}:#{volume_binding.container_dest}:#{volume_binding.options}"
    end)
  end
end
