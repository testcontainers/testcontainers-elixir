# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MinioContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.MinioContainer

  test "new/0 raises and points to MinistackContainer" do
    assert_raise ArgumentError, ~r/Testcontainers.MinistackContainer/, fn ->
      # apply/3 avoids the compile-time deprecation warning for new/0
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(MinioContainer, :new, [])
    end
  end
end
