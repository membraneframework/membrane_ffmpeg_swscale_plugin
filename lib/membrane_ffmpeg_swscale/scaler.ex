defmodule Membrane.FFmpeg.SWScale.Scaler do
  @moduledoc false

  use Membrane.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Video.Raw

  def_options target_width: [
                type: :int,
                description: "Width of the scaled video."
              ],
              target_height: [
                type: :int,
                description: "Height of the scaled video."
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
  def handle_process(:input, %Buffer{payload: payload} = buffer, _context, state) do
    %{native_state: native_state} = state

    with {:ok, frame} <- Native.scale(payload, native_state) do
      buffer = [buffer: {:output, %{buffer | payload: frame}}]

      {{:ok, buffer}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, %Raw{width: width, height: height} = caps, _context, state) do
    with {:ok, native_state} <-
           Native.create(width, height, state.target_width, state.target_height) do
      caps = %{caps | width: state.target_width, height: state.target_height}
      actions = [{:caps, {:output, caps}}]

      state = Map.put(state, :native_state, native_state)

      {{:ok, actions}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_end_of_stream(:input, _context, state) do
    {{:ok, [end_of_stream: :output, notify: {:end_of_stream, :input}]}, state}
  end

  @impl true
  def handle_prepared_to_stopped(_context, state) do
    {:ok, %{state | native_state: nil}}
  end
end
