defmodule Membrane.FFmpeg.SWScale.Mixfile do
  use Mix.Project

  @version "0.7.0"
  @github_url "https://github.com/membraneframework/membrane_ffmpeg_swscale_plugin"

  def project do
    [
      app: :membrane_ffmpeg_swscale_plugin,
      version: @version,
      elixir: "~> 1.12",
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Plugin performing video scaling, using SWScale module of [FFmpeg](https://www.ffmpeg.org/) library.",
      package: package(),
      name: "Membrane FFmpeg SWScale plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 0.9.0"},
      {:membrane_raw_video_format, "~> 0.2.0"},
      {:membrane_common_c, "~> 0.11.0"},
      {:unifex, "~> 0.7.3"},
      # Testing
      {:membrane_file_plugin, "~> 0.9", only: :test},
      {:membrane_h264_ffmpeg_plugin, "~> 0.18", only: :test},
      {:membrane_raw_video_parser_plugin, "~> 0.7", only: :test},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs", "bundlex.exs", "c_src"],
      exclude_patterns: [~r"c_src/.*/_generated.*"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.FFmpeg.SWScale]
    ]
  end
end
