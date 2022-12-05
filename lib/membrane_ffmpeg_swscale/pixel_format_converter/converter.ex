defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter do
  @moduledoc """
  This element performs conversion between pixel formats of raw video.

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
  """
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.{Buffer, RawVideo}

  @supported_pixel_formats [:I420, :I422, :I444, :RGB, :BGRA, :RGBA, :NV12, :NV21, :AYUV]

  def_input_pad :input,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats,
    availability: :always,
    demand_unit: :buffers,
    demand_mode: :auto

  def_output_pad :output,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats,
    availability: :always,
    demand_mode: :auto

  def_options format: [
                spec: RawVideo.pixel_format_t(),
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(_ctx, %__MODULE__{} = opts) do
    {[], %{native: nil, format: opts.format}}
  end

  @impl true
  def handle_stream_format(:input, %RawVideo{} = stream_format, _ctx, state) do
    new_stream_format = %RawVideo{stream_format | pixel_format: state.format}

    with {:ok, native} <-
           Native.create(
             stream_format.width,
             stream_format.height,
             stream_format.pixel_format,
             state.format
           ) do
      {[stream_format: {:output, new_stream_format}], %{state | native: native}}
    else
      {:error, reason} ->
        raise "Scaler nif context initialization failed. Reason: `#{inspect(reason)}`"
    end
  end

  @impl true
  def handle_process(:input, %Buffer{} = _buffer, _ctx, %{native: nil} = _state) do
    raise "A Buffer was received before any stream format arrived. Cannot proceed"
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    with {:ok, payload} <- Native.process(state.native, buffer.payload) do
      buffer = %Buffer{buffer | payload: payload}
      {[buffer: {:output, buffer}], state}
    else
      {:error, reason} ->
        raise "An error has ocurred while processing the buffer: `#{inspect(reason)}`"
    end
  end
end
