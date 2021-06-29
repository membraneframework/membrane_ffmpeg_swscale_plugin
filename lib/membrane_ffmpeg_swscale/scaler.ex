defmodule Membrane.FFmpeg.SWScale.Scaler do
  @moduledoc false

  use Membrane.Filter
  alias __MODULE__.Native
  alias Membrane.Buffer
  alias Membrane.Caps.Video.Raw

  def_options desired_width: [
                type: :int, 
                description: "Width of the scaled video.",
                default: 1280
              ],
              desired_height: [
                type: :int, 
                description: "Height of the scaled video.",
                default: 720
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    caps: {Raw, format: :I420, aligned: true}

  def_output_pad :output,
    caps: {Raw, format: :I420, aligned: true}

  @impl true
  def handle_init(%__MODULE__{desired_width: desired_width, desired_height: desired_height}) do
    state = %{
      desired_width: desired_width,
      desired_height: desired_height
    }

    {:ok, state}
  end

  @impl true
  # def handle_demand(:output, _size, :buffers, _context, %{encoder_ref: nil} = state) do
  #   # TODO Wait until we have an encoder - maybe sth similar here?
  #   {:ok, state}
  # end
  # 
  def handle_demand(:output, size, :buffers, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: payload}, _context, state) do
    %{scaler_ref: scaler_ref} = state

    with {:ok, frame} <- Native.scale(payload, scaler_ref),
         buffer <- wrap_frame(frame) do

      caps =
        {:output,
         %Raw{
           aligned: true,
           format: :I420,
           framerate: state.framerate,
           width: state.desired_width,
           height: state.desired_height
         }}

      actions = [{:caps, caps} | buffer]
      {{:ok, actions}, state}
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  @impl true
  def handle_caps(:input, %Raw{width: width, height: height, framerate: framerate} = _caps, _context, state) do   
    with {:ok, scaler_ref} <- Native.create(width, height, state.desired_width, state.desired_height) do
      state =
        state
        |> Map.merge(%{scaler_ref: scaler_ref, framerate: framerate})
      
      {:ok, state}
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
    {:ok, %{state | scaler_ref: nil}}
  end

  defp wrap_frame(frame) do
    %Buffer{payload: frame}
    |> then(fn buffer -> [buffer: {:output, buffer}] end)
  end
end
