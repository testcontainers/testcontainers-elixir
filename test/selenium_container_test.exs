defmodule Testcontainers.SeleniumContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.Container.SeleniumContainer

  @tag timeout: 120_000

  describe "with default configuration" do
    container(:selenium, SeleniumContainer.new())

    test "provides a ready-to-use selenium container", %{selenium: selenium} do
      assert Container.mapped_port(selenium, 4400) > 0
      assert Container.mapped_port(selenium, 4400) != 4400
      assert Container.mapped_port(selenium, 7900) > 0
      assert Container.mapped_port(selenium, 7900) != 7900
    end
  end
end
