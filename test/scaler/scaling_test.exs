defmodule ScalerTest do
  use ExUnit.Case
  import Membrane.Testing.Assertions
  alias Membrane.H264
  alias Membrane.Testing.Pipeline

  def prepare_paths() do
    # in_path = "../fixtures/input-360x640.h264" |> Path.expand(__DIR__)
    in_path = "../fixtures/input-10-720p.h264" |> Path.expand(__DIR__)
    # reference_path = "../fixtures/reference-#{filename}.raw" |> Path.expand(__DIR__)
    # out_path = "/tmp/output-scaling-200x750.h264"
    out_path = "../fixtures/output-scaling-200x750.h264" |> Path.expand(__DIR__)
    File.rm(out_path)
    # on_exit(fn -> File.rm(out_path) end)
    # {in_path, reference_path, out_path}
    {in_path, out_path}
  end

  def make_pipeline(in_path, out_path) do
    Pipeline.start_link(%Pipeline.Options{
      elements: [
        file_src: %Membrane.File.Source{location: in_path},
        parser: H264.FFmpeg.Parser,
        decoder: H264.FFmpeg.Decoder,
        scaler: %Membrane.FFmpeg.SWScale.Scaler{desired_width: 200, desired_height: 750},
        encoder: H264.FFmpeg.Encoder,
        sink: %Membrane.File.Sink{location: out_path}
      ]
    })
  end

  def assert_files_equal(file_a, file_b) do
    assert {:ok, a} = File.read(file_a)
    assert {:ok, b} = File.read(file_b)
    assert a == b
  end

  def perform_test() do
    # {in_path, ref_path, out_path} = prepare_paths(filename)
    {in_path, out_path} = prepare_paths()

    assert {:ok, pid} = make_pipeline(in_path, out_path)
    assert Pipeline.play(pid) == :ok
    assert_end_of_stream(pid, :sink, :input, 2000)
    # assert_files_equal(out_path, ref_path)
  end

  describe "ScalingPipeline should" do
    test "scale 10 720p frames to 200x750" do
      perform_test()
    end
  end

end