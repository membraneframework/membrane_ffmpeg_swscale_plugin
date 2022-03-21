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
  alias Membrane.Buffer
  alias Membrane.RawVideo
  alias Membrane.Caps.Matcher

  @supported_pixel_formats [:I420, :I422, :I444, :RGB, :BGRA, :RGBA, :NV12, :NV21, :AYUV]
  @supported_caps {RawVideo,
                   aligned: true, pixel_format: Matcher.one_of(@supported_pixel_formats)}

  def_input_pad :input,
    caps: @supported_caps,
    availability: :always,
    demand_unit: :buffers,
    demand_mode: :auto

  def_output_pad :output,
    caps: @supported_caps,
    availability: :always,
    demand_mode: :auto

  def_options format: [
                spec: RawVideo.pixel_format_t(),
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(%__MODULE__{} = opts) do
    {:ok, %{native: nil, format: opts.format}}
  end

  @impl true
  def handle_caps(:input, %RawVideo{} = caps, _ctx, state) do
    new_caps = %RawVideo{caps | pixel_format: state.format}

    with {:ok, native} <- Native.create(caps.width, caps.height, caps.pixel_format, state.format) do
      {{:ok, caps: {:output, new_caps}}, %{state | native: native}}
    else
      {:error, reason} ->
        raise "Scaler nif context initialization failed. Reason: `#{inspect(reason)}`"
    end
  end

  @impl true
  def handle_process(:input, %Buffer{} = _buffer, _ctx, %{native: nil} = _state) do
    raise "A Buffer was received before any caps arrived. Cannot proceed"
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    with {:ok, payload} <- Native.process(state.native, buffer.payload) do
      buffer = %Buffer{buffer | payload: payload}
      {{:ok, buffer: {:output, buffer}}, state}
    else
      {:error, reason} ->
        raise "An error has ocurred while processing the buffer: `#{inspect(reason)}`"
    end
  end
end
