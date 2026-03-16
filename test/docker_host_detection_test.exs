defmodule Testcontainers.DockerHostDetectionTest do
  use ExUnit.Case, async: true

  describe "parse_gateway_from_proc_route/1" do
    test "parses hex-encoded gateway from /proc/net/route content" do
      content = """
      Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT
      eth0\t00000000\t0102A8C0\t0003\t0\t0\t0\t00000000\t0\t0\t0
      eth0\t0002A8C0\t00000000\t0001\t0\t0\t0\t00FFFFFF\t0\t0\t0
      """

      assert {:ok, "192.168.2.1"} = Testcontainers.parse_gateway_from_proc_route(content)
    end

    test "parses another gateway address" do
      content = """
      Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT
      eth0\t00000000\t0100000A\t0003\t0\t0\t0\t00000000\t0\t0\t0
      """

      assert {:ok, "10.0.0.1"} = Testcontainers.parse_gateway_from_proc_route(content)
    end

    test "returns error when no default route exists" do
      content = """
      Iface\tDestination\tGateway\tFlags\tRefCnt\tUse\tMetric\tMask\tMTU\tWindow\tIRTT
      eth0\t0002A8C0\t00000000\t0001\t0\t0\t0\t00FFFFFF\t0\t0\t0
      """

      assert {:error, :no_default_route} = Testcontainers.parse_gateway_from_proc_route(content)
    end

    test "returns error for empty content" do
      assert {:error, :no_default_route} = Testcontainers.parse_gateway_from_proc_route("")
    end
  end

  describe "running_in_container?/2" do
    test "returns true when dockerenv file exists" do
      tmp_path = Path.join(System.tmp_dir!(), "test_dockerenv_#{:rand.uniform(100_000)}")
      File.write!(tmp_path, "")

      try do
        assert Testcontainers.running_in_container?(tmp_path, "/nonexistent/cgroup")
      after
        File.rm(tmp_path)
      end
    end

    test "returns true when cgroup contains docker pattern" do
      tmp_path = Path.join(System.tmp_dir!(), "test_cgroup_#{:rand.uniform(100_000)}")

      File.write!(tmp_path, """
      12:memory:/docker/abc123def456
      11:cpu:/docker/abc123def456
      """)

      try do
        assert Testcontainers.running_in_container?("/nonexistent/dockerenv", tmp_path)
      after
        File.rm(tmp_path)
      end
    end

    test "returns true when cgroup contains kubepods pattern" do
      tmp_path = Path.join(System.tmp_dir!(), "test_cgroup_kube_#{:rand.uniform(100_000)}")

      File.write!(tmp_path, """
      12:memory:/kubepods/besteffort/pod123
      """)

      try do
        assert Testcontainers.running_in_container?("/nonexistent/dockerenv", tmp_path)
      after
        File.rm(tmp_path)
      end
    end

    test "returns true when cgroup contains lxc pattern" do
      tmp_path = Path.join(System.tmp_dir!(), "test_cgroup_lxc_#{:rand.uniform(100_000)}")

      File.write!(tmp_path, """
      12:memory:/lxc/container-name
      """)

      try do
        assert Testcontainers.running_in_container?("/nonexistent/dockerenv", tmp_path)
      after
        File.rm(tmp_path)
      end
    end

    test "returns true when cgroup contains containerd pattern" do
      tmp_path = Path.join(System.tmp_dir!(), "test_cgroup_containerd_#{:rand.uniform(100_000)}")

      File.write!(tmp_path, """
      12:memory:/system.slice/containerd.service
      """)

      try do
        assert Testcontainers.running_in_container?("/nonexistent/dockerenv", tmp_path)
      after
        File.rm(tmp_path)
      end
    end

    test "returns false when neither dockerenv nor cgroup exist" do
      refute Testcontainers.running_in_container?("/nonexistent/dockerenv", "/nonexistent/cgroup")
    end

    test "returns false when cgroup exists but has no container patterns" do
      tmp_path = Path.join(System.tmp_dir!(), "test_cgroup_empty_#{:rand.uniform(100_000)}")

      File.write!(tmp_path, """
      12:memory:/user.slice/user-1000.slice
      11:cpu:/user.slice/user-1000.slice
      """)

      try do
        refute Testcontainers.running_in_container?("/nonexistent/dockerenv", tmp_path)
      after
        File.rm(tmp_path)
      end
    end
  end
end
