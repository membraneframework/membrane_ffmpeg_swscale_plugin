defmodule Membrane.FFmpeg.SWScale do
  @moduledoc false

  use Membrane.Bin
  alias __MODULE__.{Converter, Scaler}

  @supported_pixel_formats Converter.supported_pixel_formats()

  def_input_pad :input,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

  def_output_pad :output,
    accepted_format:
      %RawVideo{aligned: true, pixel_format: pixel_format}
      when pixel_format in @supported_pixel_formats

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
              ],
              format: [
                spec: RawVideo.pixel_format_t(),
                required?: true,
                description: """
                Desired pixel format of output video.
                """
              ]

  @impl true
  def handle_init(_ctx, options) do
    spawn_scaler? = options.output_width != nil or options.output_height != nil
    spawn_output_converter? = not spawn_scaler? or options.format != :I420

    spec_prefix =
      if spawn_scaler? do
        bin_input()
        |> child(:input_converter, %Converter{format: :I420})
        |> child(:scaler, %Scaler{
          output_width: options.output_width,
          output_height: options.output_height,
          use_shm?: options.use_shm?
        })
      else
        bin_input()
      end

    spec =
      if spawn_output_converter? do
        spec_prefix
        |> child(:output_converter, %Converter{format: options.format})
        |> bin_output()
      else
        spec_prefix |> bin_output()
      end

    {[spec: spec], state}
  end
end
