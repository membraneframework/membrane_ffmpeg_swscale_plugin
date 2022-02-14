defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter.Test do
  use ExUnit.Case

  alias Membrane.Caps.Video.Raw
  alias Membrane.FFmpeg.SWScale.PixelFormatConverter
  alias Membrane.Buffer

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
    state = %{native: nil, format: :RGB}

    assert {{:ok, caps: {:output, %Raw{format: :RGB}}}, state} =
             PixelFormatConverter.handle_caps(:input, @input_caps, nil, state)

    assert {{:ok, buffer: {:output, %Buffer{payload: @output}}}, _state} =
             PixelFormatConverter.handle_process(:input, %Buffer{payload: @input}, nil, state)
  end
end
