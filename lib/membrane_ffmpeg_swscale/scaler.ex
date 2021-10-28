defmodule Membrane.FFmpeg.SWScale.Scaler do
  @moduledoc """
  This element performs video scaling, using SWScale module of FFmpeg library.

  There are two options that have to be specified when creating Scaler:
  - `output_width` - desired scaled video width.
  - `output_height` - desired scaled video height.

  Both need to be even numbers.

  Scaling consists of two operations:
  - scaling itself - resizing video frame with keeping original ratio. After that operation at least one of the dimensions of the input frame match the respective dimension of the desired output size. The second one (if does not match) is smaller than its respective dimension.
  - adding paddings - if one dimension does not match after scaling, paddings have to be added. They are put on both sides of the scaled frame equally. They are either above and below the frame or on the left and right sides of it. It depends on the dimension that did not match after scaling.

  Scaler needs input in the YUV420p format, processes one frame at a time and requires getting caps with input video
  width and height. To meet all requirements either `Membrane.Element.RawVideo.Parser` or some decoder
  (e.g. `Membrane.H264.FFmpeg.Decoder`) have to precede Scaler in the pipeline.

  The output of the element is also in the YUV420p format. It has the size as specified in the options. All
  caps except for width and height are passed unchanged to the next element in the pipeline.
  """
  use Membrane.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Video.Raw

  def_options output_width: [
                type: :int,
                description: "Width of the scaled video."
              ],
              output_height: [
                type: :int,
                description: "Height of the scaled video."
              ],
              shared_payload: [
                type: :boolean,
                desciption: "If true, native scaler will use shared memory for storing frames",
                default: false
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    caps: {Raw, format: :I420, aligned: true}

  def_output_pad :output,
    caps: {Raw, format: :I420, aligned: true}

  @impl true
  def handle_init(options) do
    state =
      options
      |> Map.from_struct()
      |> Map.put(:native_state, nil)

    {:ok, state}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, _buffer, _context, %{native_state: nil} = _state) do
    raise(RuntimeError, "uninitialized state: Scaler did not receive caps")
  end

  def handle_process(
        :input,
        %Buffer{payload: payload} = buffer,
        _context,
        %{native_state: native_state, shared_payload: shared_payload} = state
      ) do
    with {:ok, frame} <- Native.scale(payload, shared_payload, native_state) do
      buffer = [buffer: {:output, %{buffer | payload: frame}}]

      {{:ok, buffer}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, %Raw{width: width, height: height} = caps, _context, state) do
    with {:ok, native_state} <-
           Native.create(width, height, state.output_width, state.output_height) do
      caps = %{caps | width: state.output_width, height: state.output_height}
      state = %{state | native_state: native_state}

      {{:ok, caps: {:output, caps}}, state}
    else
      {:error, reason} -> raise(RuntimeError, reason)
    end
  end

  @impl true
  def handle_end_of_stream(:input, _context, state) do
    {{:ok, end_of_stream: :output, notify: {:end_of_stream, :input}}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_context, state) do
    {:ok, %{state | native_state: nil}}
  end
end
