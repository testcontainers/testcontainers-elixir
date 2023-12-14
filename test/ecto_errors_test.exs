defmodule Testcontainers.EctoErrorsTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  test "repo cannot be nil" do
    assert {:error,
            %UndefinedFunctionError{
              module: Testcontainers.Repo,
              function: :config,
              arity: 0,
              reason: nil,
              message: nil
            }} =
             mysql_container(
               app: :testcontainers,
               repo: nil
             )
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
