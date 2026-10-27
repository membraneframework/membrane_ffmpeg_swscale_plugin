defmodule PixelFormatConverter.NativeTest do
  use ExUnit.Case, async: true

  alias Membrane.FFmpeg.SWScale.PixelFormatConverter.Native

  test "Reject frames shorter than the stream format" do
    assert {:ok, state} = Native.create(320, 240, :I420, :RGB)

    for frame <- [<<>>, :binary.copy(<<0>>, 115_199)] do
      assert {:error, :invalid_frame_size} = Native.process(state, frame)
    end

    assert {:ok, _frame} = Native.process(state, :binary.copy(<<0>>, 115_200))
  end
end
