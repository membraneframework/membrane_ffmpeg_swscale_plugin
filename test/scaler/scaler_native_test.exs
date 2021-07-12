defmodule Scaler.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Payload
  alias Membrane.FFmpeg.SWScale.Scaler.Native, as: Scaler

  defp make_test(input_width, input_height, output_width, output_height) do
    input_path = "../fixtures/input-10-#{input_width}x#{input_height}.raw" |> Path.expand(__DIR__)

    output_path =
      "../fixtures/output-10-#{input_width}x#{input_height}-to-#{output_width}x#{output_height}.raw"
      |> Path.expand(__DIR__)

    reference_path =
      "../fixtures/output-reference-10-#{input_width}x#{input_height}-to-#{output_width}x#{output_height}.raw"
      |> Path.expand(__DIR__)

    assert {:ok, input_data} = File.read(input_path)

    assert {:ok, native_state} =
             Scaler.create(input_width, input_height, output_width, output_height)

    File.rm(output_path)
    {:ok, output_file} = File.open(output_path, [:append])
    on_exit(fn -> File.rm(output_path) end)

    input_frame_size = div(input_width * input_height * 3, 2)
    scaled_frame_size = div(output_width * output_height * 3, 2)

    assert :ok =
             scale_frames(
               input_data,
               output_file,
               native_state,
               input_frame_size,
               scaled_frame_size
             )

    assert_files_equal(output_path, reference_path)
  end

  defp scale_frames(<<>>, _output_file, _native_state, _input_frame_size, _scaled_frame_size) do
    :ok
  end

  defp scale_frames(input_data, output_file, native_state, input_frame_size, scaled_frame_size) do
    assert <<frame::bytes-size(input_frame_size), input_data::binary>> = input_data

    assert {:ok, scaled_frame} = Scaler.scale(frame, native_state)
    assert Payload.size(scaled_frame) == scaled_frame_size

    assert :ok = IO.binwrite(output_file, Membrane.Payload.to_binary(scaled_frame))

    scale_frames(input_data, output_file, native_state, input_frame_size, scaled_frame_size)
  end

  defp assert_files_equal(path_a, path_b) do
    assert {:ok, a} = File.read(path_a)
    assert {:ok, b} = File.read(path_b)
    assert a == b
  end

  test "Scale from 360x640 to 360x640" do
    make_test(360, 640, 360, 640)
  end

  test "Scale from 360x640 to 1280x720" do
    make_test(360, 640, 1280, 720)
  end

  test "Scale from 360x640 to 200x600" do
    make_test(360, 640, 200, 600)
  end

  test "Scale from 360x640 to 640x640" do
    make_test(360, 640, 640, 640)
  end

  test "Scale from 400x400 to 1280x720" do
    make_test(400, 400, 1280, 720)
  end

  test "Scale from 400x400 to 360x640" do
    make_test(400, 400, 360, 640)
  end

  test "Scale from 400x400 to 600x600" do
    make_test(400, 400, 600, 600)
  end

  test "Scale from 1280x720 to 1600x720" do
    make_test(1280, 720, 1600, 720)
  end

  test "Scale from 1280x720 to 400x720" do
    make_test(1280, 720, 400, 720)
  end

  test "Scale from 1280x720 to 600x600" do
    make_test(1280, 720, 600, 600)
  end
end
