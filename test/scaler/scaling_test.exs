defmodule ScalerTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.H264
  alias Membrane.Testing.Pipeline

  defp prepare_paths(file_name, format) do
    input_path = "../fixtures/input-#{file_name}.#{format}" |> Path.expand(__DIR__)
    output_path = "../fixtures/output-scaling-#{file_name}.raw" |> Path.expand(__DIR__)

    File.rm(output_path)
    on_exit(fn -> File.rm(output_path) end)

    {input_path, output_path}
  end

  defp perform_test(output_path, pid) do
    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 25_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)

    assert {:ok, file} = File.read(output_path)
    assert byte_size(file) == 4_800_000
  end

  describe "ScalingPipeline should" do
    test "scale 10 raw frames to 400x800" do
      {input_path, output_path} = prepare_paths("10-1280x720", "raw")

      pipeline_options = %Pipeline.Options{
        elements: [
          file_src: %Membrane.File.Source{location: input_path},
          parser: %Membrane.Element.RawVideo.Parser{
            format: :I420,
            width: 1280,
            height: 720
          },
          scaler: %Membrane.FFmpeg.SWScale.Scaler{output_width: 400, output_height: 800},
          sink: %Membrane.File.Sink{location: output_path}
        ]
      }

      assert {:ok, pid} = Pipeline.start_link(pipeline_options)

      perform_test(output_path, pid)
    end

    test "scale 10 h264 frames to 400x800" do
      {input_path, output_path} = prepare_paths("10-1280x720", "h264")

      pipeline_options = %Pipeline.Options{
        elements: [
          file_src: %Membrane.File.Source{location: input_path},
          parser: H264.FFmpeg.Parser,
          decoder: H264.FFmpeg.Decoder,
          scaler: %Membrane.FFmpeg.SWScale.Scaler{output_width: 400, output_height: 800},
          sink: %Membrane.File.Sink{location: output_path}
        ]
      }

      assert {:ok, pid} = Pipeline.start_link(pipeline_options)

      perform_test(output_path, pid)
    end
  end
end
