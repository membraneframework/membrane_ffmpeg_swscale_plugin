defmodule Membrane.FFmpeg.SWScale.PixelFormatConverter do
  @moduledoc """
  This element performs conversion between pixel formats of raw video.
  Only formats defined in the type `t:Membrane.RawVideo.pixel_format_t()` are supported, both as input and output
  """
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.RawVideo

  def_input_pad :input,
    caps: {RawVideo, aligned: true},
    availability: :always,
    demand_unit: :buffers,
    demand_mode: :auto

  def_output_pad :output,
    caps: {RawVideo, aligned: true},
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
      {:error, reason} -> raise("libsws initialization failed. Reason: `#{inspect(reason)}`")
    end
  end

  @impl true
  def handle_process(:input, %Buffer{} = _buffer, _ctx, %{native: nil} = _state),
    do: raise("Received buffer before caps. Cannot proceed.")

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    with {:ok, payload} <- Native.process(state.native, buffer.payload) do
      buffer = %Buffer{buffer | payload: payload}
      {{:ok, buffer: {:output, buffer}}, state}
    else
      {:error, reason} ->
        raise(
          "An error has ocurred while processing the buffer. Error message: `#{inspect(reason)}`"
        )
    end
  end
end
