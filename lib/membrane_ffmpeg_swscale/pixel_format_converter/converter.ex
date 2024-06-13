defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter do
  @moduledoc """
  This module is deprecated. Use Membrane.FFmpeg.SWScaler instead.

  All options supported by #{inspect(__MODULE__)} are supported by Membrane.FFmpeg.SWScaler.
  """
  use Membrane.Filter

  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, RawVideo}

  @supported_pixel_formats [:I420, :I422, :I444, :RGB, :BGRA, :RGBA, :NV12, :NV21, :AYUV, :YUY2]

  @spec supported_pixel_formats() :: [RawVideo.pixel_format_t()]
  def supported_pixel_formats(), do: @supported_pixel_formats

  def_input_pad :input,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

  def_output_pad :output,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

  def_options format: [
                spec: RawVideo.pixel_format_t(),
                required?: true,
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(_ctx, %__MODULE__{} = opts) do
    Membrane.Logger.warning("""
    Filter #{inspect(__MODULE__)} is deprecated. Use Membrane.FFmpeg.SWScaler instead. \
    All options supported by #{inspect(__MODULE__)} are supported by Membrane.FFmpeg.SWScaler.
    """)

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
  def handle_buffer(:input, buffer, ctx, state)
      when ctx.pads.input.stream_format.pixel_format == state.format do
    {[buffer: {:output, buffer}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    with {:ok, payload} <- Native.process(state.native, buffer.payload) do
      buffer = %Buffer{buffer | payload: payload}
      {[buffer: {:output, buffer}], state}
    else
      {:error, reason} ->
        raise "An error has ocurred while processing the buffer: `#{inspect(reason)}`"
    end
  end
end
