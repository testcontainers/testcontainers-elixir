defmodule Testcontainers.EctoErrorsTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  test "repo cannot be nil" do
    assert_raise UndefinedFunctionError,
                 "function Testcontainers.Repo.config/0 is undefined (module Testcontainers.Repo is not available)",
                 fn ->
                   mysql_container(
                     app: :testcontainers,
                     repo: nil
                   )
                 end
  end

  test "repo must be atom" do
    assert_raise ArgumentError, "Not an atom: repo=\"hello\"", fn ->
      mysql_container(
        app: :testcontainers,
        repo: "hello"
      )
    end
  end

  test "app must be atom" do
    assert_raise ArgumentError, "Missing or not an atom: app=\"hello\"", fn ->
      mysql_container(app: "hello")
    end
  end
end
