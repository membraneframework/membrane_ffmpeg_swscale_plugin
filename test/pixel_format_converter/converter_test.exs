defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter.Test do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Caps.Video.Raw
  alias Membrane.FFmpeg.SWScale.PixelFormatConverter
  alias Membrane.Buffer
  alias Membrane.Testing.Pipeline

  # All black 4x4 RGB24 image
  @output [<<0x00, 0x00, 0x00>>] |> Stream.cycle() |> Enum.take(16) |> Enum.join()
  @input [<<0x00, 0x00, 0x00, 0xFF>>] |> Stream.cycle() |> Enum.take(16) |> Enum.join()

  @input_caps %Raw{
    framerate: {30, 1},
    aligned: true,
    width: 4,
    height: 4,
    format: :RGBA
  }

  test "PixelFormatConverter can convert a single frame from RGBA to RBG" do
    assert {:ok, state} = PixelFormatConverter.handle_init(%PixelFormatConverter{format: :RGB})

    assert {{:ok, caps: {:output, %Raw{format: :RGB}}}, state} =
             PixelFormatConverter.handle_caps(:input, @input_caps, nil, state)

    assert {{:ok, buffer: {:output, %Buffer{payload: output}}}, _state} =
             PixelFormatConverter.handle_process(:input, %Buffer{payload: @input}, nil, state)

    assert byte_size(output) == byte_size(@output)
    assert output == @output
  end

  test "integration test" do
    output_path = "/tmp/output-rgb-10-400x400.raw"
    reference_path = "test/fixtures/output-rgb-10-400x400.raw"

    opts = %Pipeline.Options{
      elements: [
        source: %Membrane.File.Source{location: "test/fixtures/input-10-400x400.raw"},
        parser: %Membrane.Element.RawVideo.Parser{
          format: :I420,
          width: 400,
          height: 400
        },
        converter: %PixelFormatConverter{format: :RGB},
        sink: %Membrane.File.Sink{location: output_path}
      ]
    }

    on_exit(fn -> File.rm(output_path) end)

    assert {:ok, pipeline} = Pipeline.start_link(opts)
    Pipeline.play(pipeline)

    assert_pipeline_playback_changed(pipeline, :prepared, :playing)
    assert_end_of_stream(pipeline, :sink)
    Pipeline.stop_and_terminate(pipeline, blocking: true)
    assert_pipeline_playback_changed(pipeline, :playing, :prepared)

    assert File.exists?(output_path)
    assert File.read!(output_path) == File.read!(reference_path)
  end
end
