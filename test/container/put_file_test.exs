defmodule Testcontainers.Container.PutFileTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  container(:nginx, %Test.NginxContainer{})

  test "upload file", %{nginx: _nginx} do
    # should succeed
  end
end
