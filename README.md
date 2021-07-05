# Membrane FFmpeg SWScale plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_ffmpeg_swscale_plugin.svg)](https://hex.pm/packages/membrane_ffmpeg_swscale_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_ffmpeg_swscale_plugin/)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swscale_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_ffmpeg_swscale_plugin)

Plugin performing video scaling, using SWScale module of [FFmpeg](https://www.ffmpeg.org/) library.

It is a part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

Add the following line to your `deps` in `mix.exs`. Run `mix deps.get`.

```elixir
{:membrane_ffmpeg_swscale_plugin, "~> 0.1.0"}
```

You also need to have [FFmpeg](https://www.ffmpeg.org/) library installed.
For usage on Windows, see `Using on Windows` section below.

## Sample usage

```elixir
defmodule Scaling.Pipeline do
  use Membrane.Pipeline

  @doc false
  @impl true
  def handle_init(_) do
    children = [
      file_src: %Membrane.File.Source{location: "/tmp/input.raw"},
      parser: %Membrane.Element.RawVideo.Parser{format: :I420, width: 1280, height: 720},
      scaler: %Membrane.FFmpeg.SWScale.Scaler{output_width: 640, output_height: 640},
      file_sink: %Membrane.File.Sink{location: "/tmp/output.raw"}
    ]

    links = [
      link(:file_src)
      |> to(:parser)
      |> to(:scaler)
      |> to(:file_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
