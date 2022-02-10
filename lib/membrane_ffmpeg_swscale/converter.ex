defmodule Membrane.FFmpeg.SWScale.PixFmtConverter do
  @moduledoc """
  Element wrapping functionality of FFmpeg's `libswscale` of raw video pixel format conversion and resolution scaling.
  """
  use Membrane.Filter

  alias __MODULE__.Native
  alias Membrane.Buffer

  def_input_pad :input,
    caps: {Membrane.Caps.Video.Raw, aligned: true},
    availability: :always,
    demand_unit: :buffers

  def_output_pad :output,
    caps: {Membrane.Caps.Video.Raw, aligned: true},
    availability: :always

  def_options width: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Desired width of output video.
                """
              ],
              height: [
                spec: non_neg_integer() | nil,
                default: nil,
                description: """
                Desired height of output video.
                """
              ],
              format: [
                spec: Membrane.Caps.Video.Raw.format_t() | nil,
                default: nil,
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(%__MODULE__{} = opts) do
    opts =
      Map.from_struct(opts) |> Enum.reject(fn {_key, value} -> is_nil(value) end) |> Map.new()

    validate_opts(opts)

    {:ok, %{native: nil, options: opts}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_caps(:input, %Membrane.Caps.Video.Raw{} = caps, _ctx, state) do
    new_caps =
      Map.from_struct(caps)
      |> Map.merge(state.options)
      |> then(&struct!(Membrane.Caps.Video.Raw, Enum.to_list(&1)))

    with {:ok, native} <- Native.create(caps.width, caps.height, caps.format, new_caps.format),
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

  defp validate_opts(opts) do
    width? = Map.has_key?(opts, :width)
    height? = Map.has_key?(opts, :height)

    if (width? and not height?) or (height? and not width?) do
      raise("You have to specify both width and height or neither.")
    end
  end
end
