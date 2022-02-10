defmodule Membrane.FFmpeg.SWScale.PixFmtConverter.Test do
  use ExUnit.Case

  alias Membrane.Caps.Video.Raw
  alias Membrane.FFmpeg.SWScale.PixFmtConverter
  alias Membrane.Buffer

  # All black 4x4 RGB24 image
  @input_frame %Buffer{payload: <<0::384>>}

  @input_caps %Raw{
    framerate: {30, 1},
    aligned: true,
    width: 4,
    height: 4,
    format: :RGB
  }

  test "PixFmtConverter can convert a single frame from RGB to YUV420P" do
    state = %{native: nil, format: :I420}

    assert {{:ok, caps: {:output, %Raw{format: :I420}}}, state} =
             PixFmtConverter.handle_caps(:input, @input_caps, nil, state)

    assert {{:ok, buffer: {:output, %Buffer{payload: <<_data::192>>}}}, _state} =
             PixFmtConverter.handle_process(:input, @input_frame, nil, state)
  end
end
