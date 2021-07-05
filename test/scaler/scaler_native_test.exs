defmodule Scaler.NativeTest do
  use ExUnit.Case, async: true
  alias Membrane.Payload
  alias Membrane.FFmpeg.SWScale.Scaler.Native, as: Scaler

  test "Scale 1 720p frame" do
    in_path = "../fixtures/input-10-1280x720.raw" |> Path.expand(__DIR__)

    assert {:ok, file} = File.read(in_path)
    assert {:ok, native_state} = Scaler.create(1280, 720, 640, 640)
    assert <<frame::bytes-size(1_382_400), _::binary>> = file
    assert {:ok, scaled_frame} = Scaler.scale(frame, native_state)
    assert Payload.size(scaled_frame) == 614_400
  end
end
