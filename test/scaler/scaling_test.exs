defmodule SWScalerTest do
  use ExUnit.Case

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.FFmpeg.SWScaler
  alias Membrane.{H264, RawVideo}
  alias Membrane.Testing.Pipeline

  @input_stream_format %RawVideo{
    width: 1920,
    height: 1080,
    aligned: true,
    pixel_format: :I420,
    framerate: nil
  }

  @output_stream_format %RawVideo{
    width: 640,
    height: 360,
    aligned: true,
    pixel_format: :I420,
    framerate: nil
  }

  defp prepare_paths(file_name, format) do
    input_path = "../fixtures/input-#{file_name}.#{format}" |> Path.expand(__DIR__)
    output_path = "../fixtures/output-scaling-#{file_name}.raw" |> Path.expand(__DIR__)

    File.rm(output_path)
    on_exit(fn -> File.rm(output_path) end)

    {input_path, output_path}
  end

  defp perform_test(output_path, pid) do
    assert_end_of_stream(pid, :sink, :input, 25_000)
    Pipeline.terminate(pid)

    assert {:ok, file} = File.read(output_path)
    assert byte_size(file) == 4_800_000
  end

  describe "ScalingPipeline should" do
    test "scale 10 raw frames to 400x800" do
      {input_path, output_path} = prepare_paths("10-1280x720", "raw")

      pipeline =
        Pipeline.start_link_supervised!(
          spec:
            child(:file_src, %Membrane.File.Source{location: input_path})
            |> child(
              :parser,
              %Membrane.RawVideo.Parser{
                pixel_format: :I420,
                width: 1280,
                height: 720
              }
            )
            |> child(
              :scaler,
              %SWScaler{output_width: 400, output_height: 800}
            )
            |> child(:sink, %Membrane.File.Sink{location: output_path})
        )

      perform_test(output_path, pipeline)
    end

    test "scale 10 h264 frames to 400x800" do
      {input_path, output_path} = prepare_paths("10-1280x720", "h264")

      pipeline =
        Pipeline.start_link_supervised!(
          spec:
            child(:file_src, %Membrane.File.Source{location: input_path})
            |> child(:parser, H264.Parser)
            |> child(:decoder, H264.FFmpeg.Decoder)
            |> child(:scaler, %SWScaler{
              output_width: 400,
              output_height: 800
            })
            |> child(:sink, %Membrane.File.Sink{location: output_path})
        )

      perform_test(output_path, pipeline)
    end
  end

  describe "output dimensions should" do
    test "be calculated if only width is provided" do
      assert {[], state} =
               SWScaler.handle_init(%{}, %SWScaler{
                 output_width: 640,
                 output_height: nil,
                 use_shm?: false
               })

      assert {[stream_format: {:output, @output_stream_format}],
              %{output_width: 640, output_height: 360}} =
               SWScaler.handle_stream_format(
                 :input,
                 @input_stream_format,
                 %{},
                 state
               )
    end

    test "be calculated if only height is provided" do
      assert {[], state} =
               SWScaler.handle_init(%{}, %SWScaler{
                 output_width: nil,
                 output_height: 360,
                 use_shm?: false
               })

      assert {[stream_format: {:output, @output_stream_format}],
              %{output_width: 640, output_height: 360}} =
               SWScaler.handle_stream_format(
                 :input,
                 @input_stream_format,
                 %{},
                 state
               )
    end

    test "raise if neither width nor height is provided" do
      assert_raise RuntimeError, "At least one dimension needs to be provided", fn ->
        SWScaler.handle_init(%{}, %SWScaler{
          output_width: nil,
          output_height: nil,
          use_shm?: false
        })
      end
    end
  end
end
