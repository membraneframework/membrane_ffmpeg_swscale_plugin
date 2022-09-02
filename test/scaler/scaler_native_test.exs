defmodule Scaler.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.FFmpeg.SWScale.Scaler.Native, as: Scaler
  alias Membrane.Payload

  defp scaling_test({input_width, input_height, output_width, output_height}) do
    input_path = "../fixtures/input-10-#{input_width}x#{input_height}.raw" |> Path.expand(__DIR__)

    reference_path =
      "../fixtures/output-reference-10-#{input_width}x#{input_height}-to-#{output_width}x#{output_height}.raw"
      |> Path.expand(__DIR__)

    assert {:ok, input_data} = File.read(input_path)

    assert {:ok, native_state} =
             Scaler.create(input_width, input_height, output_width, output_height)

    input_frame_size = div(input_width * input_height * 3, 2)
    scaled_frame_size = div(output_width * output_height * 3, 2)

    assert scaled_data = scale(input_data, native_state, input_frame_size, scaled_frame_size)

    assert {:ok, reference_data} = File.read(reference_path)
    assert byte_size(reference_data) == byte_size(scaled_data)
    assert reference_data == scaled_data
  end

  defp scale(input_data, native_state, input_frame_size, scaled_frame_size) do
    for <<frame::bytes-size(input_frame_size) <- input_data>> do
      assert {:ok, scaled_frame} = Scaler.scale(frame, false, native_state)
      assert Payload.size(scaled_frame) == scaled_frame_size

      Membrane.Payload.to_binary(scaled_frame)
    end
    |> Enum.join()
  end

  [
    {360, 640, 360, 640},
    {360, 640, 1280, 720},
    {360, 640, 200, 600},
    {360, 640, 640, 640},
    {400, 400, 1280, 720},
    {400, 400, 360, 640},
    {400, 400, 600, 600},
    {1280, 720, 1600, 720},
    {1280, 720, 400, 720},
    {1280, 720, 600, 600}
  ]
  |> Enum.each(fn {in_width, in_height, out_width, out_height} = resolutions ->
    test "Scale from #{in_width}x#{in_height} to #{out_width}x#{out_height}" do
      unquote(Macro.escape(resolutions))
      |> scaling_test()
    end
  end)
end
