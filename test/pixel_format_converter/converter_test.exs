defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter.Test do
  use ExUnit.Case

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, RawVideo}
  alias Membrane.FFmpeg.SWScale.PixelFormatConverter
  alias Membrane.Testing.Pipeline

  test "PixelFormatConverter can convert a single frame from RGB to I420" do
    input_stream_format = %RawVideo{
      framerate: {30, 1},
      aligned: true,
      width: 6,
      height: 4,
      pixel_format: :RGB
    }

    pixels_count = input_stream_format.width * input_stream_format.height

    rgb_input = <<0::8, 0::8, 0::8>> |> String.duplicate(pixels_count)

    i420_output =
      [
        # Y=16, Cb=128, Cr=128 the values for black according to proposal ITU 709 (Rec 709 or BT.709) and ITU 601 (HD and SD).
        # https://en.wikipedia.org/wiki/Rec._709#Digital_representation
        <<16::8>> |> String.duplicate(pixels_count),
        <<128::8>> |> String.duplicate(pixels_count |> div(4)),
        <<128::8>> |> String.duplicate(pixels_count |> div(4))
      ]
      |> Enum.join()

    assert {[], state} =
             PixelFormatConverter.handle_init(nil, %PixelFormatConverter{format: :I420})

    assert {[stream_format: {:output, %RawVideo{pixel_format: :I420}}], state} =
             PixelFormatConverter.handle_stream_format(:input, input_stream_format, nil, state)

    assert {[buffer: {:output, %Buffer{payload: output}}], _state} =
             PixelFormatConverter.handle_process(:input, %Buffer{payload: rgb_input}, nil, state)

    assert bit_size(output) == pixels_count * 12
    assert output == i420_output
  end

  @tag :tmp_dir
  test "integration test", %{tmp_dir: tmp_dir} do
    output_path = Path.join(tmp_dir, "output-rgb-10-400x400.raw")
    reference_path = "../fixtures/output-rgb-10-400x400.raw" |> Path.expand(__DIR__)
    input_path = "../fixtures/input-10-400x400.raw" |> Path.expand(__DIR__)

    pipeline =
      Pipeline.start_link_supervised!(
        structure:
          child(:source, %Membrane.File.Source{location: input_path})
          |> child(:parser, %Membrane.RawVideo.Parser{
            pixel_format: :I420,
            width: 400,
            height: 400
          })
          |> child(:converter, %PixelFormatConverter{format: :RGB})
          |> child(:sink, %Membrane.File.Sink{location: output_path})
      )

    assert_pipeline_play(pipeline)
    assert_end_of_stream(pipeline, :sink, :input, 10_000)

    Pipeline.terminate(pipeline, blocking: true)

    assert File.exists?(output_path)
    assert File.read!(output_path) == File.read!(reference_path)
  end
end
