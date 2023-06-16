defmodule Membrane.FFmpeg.SWScale.Scaler do
  @moduledoc """
  This element performs video scaling, using SWScale module of FFmpeg library.

  There are two options that can be specified when creating Scaler:
  - `output_width` - desired scaled video width.
  - `output_height` - desired scaled video height.

  Both need to be even numbers.

  Note that if only one dimension is specified (either `output_width` or `output_height`),
  the other dimension is calculated on `handle_stream_format` callback based on input dimensions.

  Scaling consists of two operations:
  - scaling itself - resizing video frame with keeping original ratio. After that operation at least one of the dimensions of the input frame match the respective dimension of the desired output size. The second one (if does not match) is smaller than its respective dimension.
  - adding paddings - if one dimension does not match after scaling, paddings have to be added. They are put on both sides of the scaled frame equally. They are either above and below the frame or on the left and right sides of it. It depends on the dimension that did not match after scaling.

  Scaler needs input in the YUV420p format, processes one frame at a time and requires getting stream format with input video
  width and height. To meet all requirements either `Membrane.Element.RawVideo.Parser` or some decoder
  (e.g. `Membrane.H264.FFmpeg.Decoder`) have to precede Scaler in the pipeline.

  The output of the element is also in the YUV420p format. It has the size as specified in the options. All
  stream format except for width and height are passed unchanged to the next element in the pipeline.
  """
  use Membrane.Filter
  alias __MODULE__.Native
  alias Membrane.{Buffer, RawVideo}

  def_options output_width: [
                spec: non_neg_integer(),
                default: nil,
                description: "Width of the scaled video."
              ],
              output_height: [
                spec: non_neg_integer(),
                default: nil,
                description: "Height of the scaled video."
              ],
              use_shm?: [
                spec: boolean(),
                description:
                  "If true, native scaler will use shared memory (via `t:Shmex.t/0`) for storing frames",
                default: false
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420, aligned: true}

  def_output_pad :output,
    demand_mode: :auto,
    accepted_format: %RawVideo{pixel_format: :I420, aligned: true}

  @impl true
  def handle_init(_ctx, %{output_width: nil, output_height: nil}) do
    raise "At least one dimension needs to be provided"
  end

  @impl true
  def handle_init(_ctx, options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:native_state, nil)

    {[], state}
  end

  @impl true
  def handle_process(
        :input,
        %Buffer{payload: payload} = buffer,
        _context,
        %{native_state: native_state, use_shm?: use_shm?} = state
      ) do
    case Native.scale(payload, use_shm?, native_state) do
      {:ok, frame} ->
        {[buffer: {:output, %{buffer | payload: frame}}], state}

      {:error, reason} ->
        raise "Scaling failed: #{reason}"
    end
  end

  @impl true
  def handle_stream_format(
        :input,
        %RawVideo{width: width, height: height} = stream_format,
        _context,
        state
      ) do
    state = calculate_output_dims(state, {width, height})

    case Native.create(width, height, state.output_width, state.output_height) do
      {:ok, native_state} ->
        stream_format = %{stream_format | width: state.output_width, height: state.output_height}
        state = %{state | native_state: native_state}

        {[stream_format: {:output, stream_format}], state}

      {:error, reason} ->
        raise inspect(reason)
    end
  end

  defp calculate_output_dims(%{output_width: nil} = state, {width, height}) do
    output_width = div(state.output_height * width, height)
    output_width = output_width - rem(output_width, 4)
    %{state | output_width: output_width}
  end

  defp calculate_output_dims(%{output_height: nil} = state, {width, height}) do
    output_height = div(state.output_width * height, width)
    output_height = output_height - rem(output_height, 4)
    %{state | output_height: output_height}
  end

  defp calculate_output_dims(state, _original_dim), do: state
end
