defmodule Meetup.MixProject do
  use Mix.Project

  @app :testcontainers_elixir
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "#{@app}",
      archives: [mix_gleam: "~> 0.6.1"],
      compilers: [:gleam | Mix.compilers()],
      aliases: [
        "deps.get": ["deps.get", "gleam.deps.get"]
      ],
      erlc_paths: [
        "build/dev/erlang/#{@app}/_gleam_artefacts",
        # For Gleam < v0.25.0
        "build/dev/erlang/#{@app}/build"
      ],
      erlc_include_path: "build/dev/erlang/#{@app}/include",
      start_permanent: Mix.env() == :prod,
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

  # Specifies which paths to compile per environment.
  # , "test/support"]
  defp elixirc_paths(:test), do: ["lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:mix_gleam, "~> 0.6"},
      {:gleam_hackney, "~> 1.1"},
      {:gleam_http, "~> 3.5"}
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
