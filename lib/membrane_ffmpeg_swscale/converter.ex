defmodule Membrane.FFmpeg.SWScale.Converter do
  @moduledoc """
  This element performs video scaling and conversion between pixel formats of raw video, using SWScale module of FFmpeg library.

  Following options that can be specified when creating Scaler:
  - `format` - desired pixel format of the output video.
  - `output_width` - desired scaled video width. Needs to be an even number.
  - `output_height` - desired scaled video height. Needs to be an even number.
  - `use_shm?` - indicator if native scaler will use shared memory (via `t:Shmex.t/0`) for storing frames. Default to false.

  Only the following pixel formats are supported, both as input and output:
  - I420
  - I422
  - I444
  - RGB
  - BGRA
  - RGBA
  - NV12
  - NV21
  - AYUV
  - YUY2

  If `format` is not specyfied, output video will have the same format as input.

  If neither `output_width` nor `output_height` is specyfied, video frames will not be scaled.

  If only one dimension is specified (either `output_width` or `output_height`), the other dimension is calculated on `handle_stream_format` callback based on input dimensions.

  Scaling consists of two operations:
  - scaling itself - resizing video frame with keeping original ratio. After that operation at least one of the dimensions of the input frame match the respective dimension of the desired output size. The second one (if does not match) is smaller than its respective dimension.
  - adding paddings - if one dimension does not match after scaling, paddings have to be added. They are put on both sides of the scaled frame equally. They are either above and below the frame or on the left and right sides of it. It depends on the dimension that did not match after scaling.

  #{inspect(__MODULE__)} requires getting stream format with input video width and height. To meet all requirements either `Membrane.Element.RawVideo.Parser` or some decoder (e.g. `Membrane.H264.FFmpeg.Decoder`) have to precede #{inspect(__MODULE__)} in the pipeline.
  """

  use Membrane.Filter

  require Membrane.Logger

  alias Membrane.FFmpeg.SWScale.PixelFormatConverter
  alias Membrane.FFmpeg.SWScale.Scaler
  alias Membrane.RawVideo

  @supported_pixel_formats PixelFormatConverter.supported_pixel_formats()

  def_input_pad :input,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

  def_output_pad :output,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

  def_options output_width: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: "Width of the scaled video."
              ],
              output_height: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: "Height of the scaled video."
              ],
              use_shm?: [
                spec: boolean(),
                default: false,
                description:
                  "If true, native scaler will use shared memory (via `t:Shmex.t/0`) for storing frames"
              ],
              format: [
                spec: RawVideo.pixel_format() | nil,
                default: nil,
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(_ctx, options) do
    with %__MODULE__{output_width: nil, output_height: nil, format: nil} <- options do
      Membrane.Logger.warning("""
      Neither :output_width, :output_height nor :format was specyfied, so this filter won't do any operation on buffers.
      """)
    end

    scale? = options.output_width != nil or options.output_height != nil

    state =
      Map.from_struct(options)
      |> Map.merge(%{
        scaler: nil,
        input_converter: nil,
        output_converter: nil,
        scale?: scale?
      })

    {[], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state),
    do: do_handle_stream_format(stream_format, state)

  defp do_handle_stream_format(stream_format, state) when state.scale? do
    state =
      case state do
        %{output_width: nil} ->
          output_width =
            caluculate_missing_dimension(
              state.output_height,
              stream_format.width,
              stream_format.height
            )

          %{state | output_width: output_width}

        %{output_height: nil} ->
          output_height =
            caluculate_missing_dimension(
              state.output_width,
              stream_format.height,
              stream_format.width
            )

          %{state | output_height: output_height}

        state ->
          state
      end

    output_pixel_format = state.format || stream_format.pixel_format

    state =
      with {:ok, input_converter} <-
             PixelFormatConverter.Native.create(
               stream_format.width,
               stream_format.height,
               stream_format.pixel_format,
               :I420
             ),
           {:ok, scaler} <-
             Scaler.Native.create(
               stream_format.width,
               stream_format.height,
               state.output_width,
               state.output_height
             ),
           {:ok, output_converter} <-
             PixelFormatConverter.Native.create(
               state.output_width,
               state.output_height,
               :I420,
               output_pixel_format
             ) do
        Map.merge(state, %{
          input_converter: input_converter,
          scaler: scaler,
          output_converter: output_converter
        })
      else
        error -> raise "Error while creating native: #{inspect(error)}"
      end

    stream_format = %{
      stream_format
      | width: state.output_width,
        height: state.output_height,
        pixel_format: output_pixel_format
    }

    {[stream_format: {:output, stream_format}], state}
  end

  defp do_handle_stream_format(stream_format, state) when not state.scale? do
    output_pixel_format = state.format || stream_format.pixel_format

    state =
      with {:ok, output_converter} <-
             PixelFormatConverter.Native.create(
               stream_format.width,
               stream_format.height,
               stream_format.pixel_format,
               output_pixel_format
             ) do
        %{state | output_converter: output_converter}
      else
        error -> raise "Error while creating native: #{inspect(error)}"
      end

    stream_format = %{stream_format | pixel_format: output_pixel_format}
    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    stream_format = ctx.pads.input.stream_format
    output_pixel_format = state.format || stream_format.pixel_format

    payload =
      if state.scale? do
        buffer.payload
        |> maybe_convert(state.input_converter, stream_format.pixel_format, :I420)
        |> scale(state.scaler, state.use_shm?)
        |> maybe_convert(state.output_converter, :I420, output_pixel_format)
      else
        buffer.payload
        |> maybe_convert(state.output_converter, stream_format.pixel_format, output_pixel_format)
      end

    buffer = %{buffer | payload: payload}
    {[buffer: {:output, buffer}], state}
  end

  defp scale(payload, native_scaler, use_shm?) do
    with {:ok, payload} <- Scaler.Native.scale(payload, use_shm?, native_scaler) do
      payload
    else
      {:error, reason} ->
        raise "An error has ocurred while scaling the buffer: `#{inspect(reason)}`"
    end
  end

  defp maybe_convert(payload, _native_converter, format, format) do
    payload
  end

  defp maybe_convert(payload, native_converter, _source_format, _target_format) do
    with {:ok, payload} <- PixelFormatConverter.Native.process(native_converter, payload) do
      payload
    else
      {:error, reason} ->
        raise "An error has ocurred while processing the buffer: `#{inspect(reason)}`"
    end
  end

  defp caluculate_missing_dimension(present_dim, analogical_input_dim, opposite_input_dim) do
    output_dim = div(present_dim * analogical_input_dim, opposite_input_dim)
    output_dim + rem(output_dim, 2)
  end
end
