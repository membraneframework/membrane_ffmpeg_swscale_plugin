defmodule Membrane.FFmpeg.SWScale.PixFmtConverter do
  @moduledoc """
  Element wrapping functionality of FFmpeg's `libswscale` of raw video pixel format conversion and resolution scaling.
  """
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Video.Raw

  def_input_pad :input,
    caps: {Raw, aligned: true},
    availability: :always,
    demand_unit: :buffers

  def_output_pad :output,
    caps: {Raw, aligned: true},
    availability: :always

  def_options format: [
                spec: Raw.format_t(),
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(%__MODULE__{} = opts) do
    {:ok, %{native: nil, format: opts.format}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_caps(:input, %Raw{} = caps, _ctx, state) do
    new_caps = %Raw{caps | format: state.format}

    with {:ok, native} <- Native.create(caps.width, caps.height, caps.format, state.format),
         do: {{:ok, caps: {:output, new_caps}}, %{state | native: native}}
  end

  @impl true
  def handle_process(:input, %Buffer{} = _buffer, _ctx, %{native: nil} = _state),
    do: raise("Received buffer before caps. Cannot proceed.")

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {:ok, payload} = Native.process(state.native, buffer.payload)
    buffer = %Buffer{buffer | payload: payload}
    {{:ok, buffer: {:output, buffer}}, state}
  end
end
