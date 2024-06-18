defmodule Membrane.FFmpeg.SWScale.Scaler do
  @moduledoc """
  This module is deprecated. Use Membrane.FFmpeg.SWScale.Converter instead.

  All options supported by #{inspect(__MODULE__)} are supported by Membrane.FFmpeg.SWScale.Converter.
  """

  use Membrane.Filter

  require Membrane.Logger

  alias __MODULE__.Native
  alias Membrane.{Buffer, RawVideo}

  def_options output_width: [
                spec: non_neg_integer(),
                default: nil,
                description: "Width of the scaled video."
              ],
              output_height: [
                spec: non_neg_integer(),
                default: nil,
                description: "Height of the scaled video."
              ],
              use_shm?: [
                spec: boolean(),
                description:
                  "If true, native scaler will use shared memory (via `t:Shmex.t/0`) for storing frames",
                default: false
              ]

  def_input_pad :input,
    accepted_format: %RawVideo{pixel_format: :I420, aligned: true}

  def_output_pad :output,
    accepted_format: %RawVideo{pixel_format: :I420, aligned: true}

  @impl true
  def handle_init(_ctx, %{output_width: nil, output_height: nil}) do
    raise "At least one dimension needs to be provided"
  end

  @impl true
  def handle_init(_ctx, options) do
    Membrane.Logger.warning("""
    Filter #{inspect(__MODULE__)} is deprecated. Use Membrane.FFmpeg.SWScale.Converter instead. \
    All options supported by #{inspect(__MODULE__)} are supported by Membrane.FFmpeg.SWScale.Converter.
    """)

    state =
      options
      |> Map.from_struct()
      |> Map.put(:native_state, nil)

    {[], state}
  end

  @impl true
  def handle_buffer(
        :input,
        %Buffer{payload: payload} = buffer,
        _context,
        %{native_state: native_state, use_shm?: use_shm?} = state
      ) do
    case Native.scale(payload, use_shm?, native_state) do
      {:ok, frame} ->
        {[buffer: {:output, %{buffer | payload: frame}}], state}

      {:error, reason} ->
        raise "Scaling failed: #{reason}"
    end
  end

  @impl true
  def handle_stream_format(
        :input,
        %RawVideo{width: width, height: height} = stream_format,
        _context,
        state
      ) do
    state = calculate_output_dims(state, {width, height})

    case Native.create(width, height, state.output_width, state.output_height) do
      {:ok, native_state} ->
        stream_format = %{stream_format | width: state.output_width, height: state.output_height}
        state = %{state | native_state: native_state}

        {[stream_format: {:output, stream_format}], state}

      {:error, reason} ->
        raise inspect(reason)
    end
  end

  defp calculate_output_dims(%{output_width: nil} = state, {width, height}) do
    output_width = div(state.output_height * width, height)
    output_width = output_width + rem(output_width, 2)
    %{state | output_width: output_width}
  end

  defp calculate_output_dims(%{output_height: nil} = state, {width, height}) do
    output_height = div(state.output_width * height, width)
    output_height = output_height + rem(output_height, 2)
    %{state | output_height: output_height}
  end

  defp calculate_output_dims(state, _original_dim), do: state
end
