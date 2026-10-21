# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MinioContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.MinioContainer

  test "new/0 raises and points to MinistackContainer" do
    assert_raise ArgumentError, ~r/Testcontainers.MinistackContainer/, fn ->
      apply(MinioContainer, :new, [])
    end
  end
end
