defmodule ScalerTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.H264
  alias Membrane.Testing.Pipeline

  def prepare_paths(filename) do
    in_path = "../fixtures/input-#{filename}.h264" |> Path.expand(__DIR__)
    out_path = "../fixtures/output-scaling-#{filename}.h264" |> Path.expand(__DIR__)
    File.rm(out_path)
    {in_path, out_path}
  end

  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        parser: H264.FFmpeg.Parser,
        decoder: H264.FFmpeg.Decoder,
        scaler: %Membrane.FFmpeg.SWScale.Scaler{target_width: 400, target_height: 800},
        encoder: H264.FFmpeg.Encoder,
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end

  def perform_test(filename) do
    {in_path, out_path} = prepare_paths(filename)

    assert {:ok, pid} = make_pipeline(in_path, out_path)
    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 25_000)
  end

  describe "ScalingPipeline should" do
    test "scale 10 720p frames to 640x640" do
      perform_test("10-1280x720")
    end

    # test "scale 3565 360x640 frames to 640x640" do
    #   perform_test("3565-360x640")
    # end
  end
end
