defmodule TestcontainersElixir.MixProject do
  use Mix.Project

  @app :testcontainers
  @version "1.0.0"

  def project do
    [
      app: @app,
      name: "#{@app}",
      version: @version,
      description: "Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.",
      elixir: "~> 1.15",
      licenses: ["MIT"],
      source_url: "https://github.com/jarlah/testcontainers-elixir",
      homepage_url: "https://github.com/jarlah/testcontainers-elixir",
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ex_license, "~> 0.1.0"},
      {:docker_engine_api,
       git: "https://github.com/jarlah/docker-engine-api-elixir.git", tag: "1.43.0.5-hackney"},
      {:myxql, "~> 0.6.0", only: [:dev, :test]},
      {:postgrex, "~> 0.17", only: [:dev, :test]},
      {:redix, "~> 1.2", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
