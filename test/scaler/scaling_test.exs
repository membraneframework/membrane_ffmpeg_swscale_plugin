defmodule ScalerTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.H264
  alias Membrane.Testing.Pipeline

  describe "ScalingPipeline should" do
    test "scale 10 raw frames to 400x800" do
      {in_path, out_path} = prepare_paths("10-1280x720", "raw")
      assert {:ok, pid} = make_pipeline_raw(in_path, out_path)

      perform_test(out_path, pid)
    end

    test "scale 10 h264 frames to 400x800" do
      {in_path, out_path} = prepare_paths("10-1280x720", "h264")
      assert {:ok, pid} = make_pipeline_h264(in_path, out_path)

      perform_test(out_path, pid)
    end
  end

  defp perform_test(out_path, pid) do
    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 25_000)
    Pipeline.stop_and_terminate(pid, blocking?: true)

    assert {:ok, file} = File.read(out_path)
    assert byte_size(file) == 4_800_000
  end

  defp prepare_paths(filename, format) do
    in_path = "../fixtures/input-#{filename}.#{format}" |> Path.expand(__DIR__)
    out_path = "../fixtures/output-scaling-#{filename}.raw" |> Path.expand(__DIR__)
    File.rm(out_path)
    {in_path, out_path}
  end

  defp make_pipeline_raw(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        parser: %Membrane.Element.RawVideo.Parser{format: :I420, width: 1280, height: 720},
        scaler: %Membrane.FFmpeg.SWScale.Scaler{output_width: 400, output_height: 800},
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end

  defp make_pipeline_h264(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        parser: H264.FFmpeg.Parser,
        decoder: H264.FFmpeg.Decoder,
        scaler: %Membrane.FFmpeg.SWScale.Scaler{output_width: 400, output_height: 800},
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end
end
