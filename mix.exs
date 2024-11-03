defmodule TestcontainersElixir.MixProject do
  use Mix.Project

  @app :testcontainers
  @version "1.10.5"
  @source_url "https://github.com/testcontainers/testcontainers-elixir"

  def project do
    [
      app: @app,
      name: "#{@app}",
      version: @version,
      description:
        "Testcontainers is an Elixir library that supports ExUnit tests, providing lightweight, throwaway instances of common databases, Selenium web browsers, or anything else that can run in a Docker container.",
      elixir: "~> 1.13",
      source_url: @source_url,
      homepage_url: @source_url,
      aliases: aliases(),
      deps: deps(),
      package: [
        links: %{"GitHub" => @source_url},
        licenses: ["MIT"]
      ],
      test_coverage: [
        summary: [threshold: 60],
        ignore_modules: [
          TestHelper,
          Inspect.Testcontainers.TestUser,
          ~r/DockerEngineAPI/
        ]
      ],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "docker_engine_api", "test/support"]
  defp elixirc_paths(_), do: ["lib", "docker_engine_api"]

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
      {:elixir_uuid, "~> 1.2"},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:tesla, "~> 1.7"},
      {:jason, "~> 1.4"},
      {:hackney, "~> 1.20"},
      # ecto module
      {:ecto_sql, "~> 3.3", optional: true},
      {:ecto, "~> 3.3", optional: true},
      # mysql
      {:myxql, "~> 0.4", only: [:dev, :test]},
      # postgres
      {:postgrex, "~> 0.14", only: [:dev, :test]},
      # redis
      {:redix, "~> 1.0", only: [:dev, :test]},
      # ceph and minio
      {:ex_aws, "~> 2.1", only: [:dev, :test]},
      {:ex_aws_s3, "~> 2.0", only: [:dev, :test]},
      {:sweet_xml, "~> 0.6", only: [:dev, :test]},
      # cassandra
      {:xandra, "~> 0.14", only: [:dev, :test]},
      # kafka
      {:kafka_ex, "~> 0.13", only: [:dev, :test]},
      # Zookeeper
      {:erlzk, "~> 0.6.2", only: [:dev, :test]},
      # RabbitMQ
      {:amqp, "~> 3.3", only: [:dev, :test]},
      # EMQX
      {:tortoise311, "~> 0.12.0", only: [:dev, :test]},
      # For watching directories for file changes in mix task
      {:fs, "~> 8.6"}
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
      setup: ["deps.get"],
      test: ["test --stale"]
    ]
  end
end
