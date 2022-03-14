defmodule Membrane.FFmpeg.SWScale.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      scaler: [
        interface: :nif,
        sources: ["scaler/scaler.c"],
        pkg_configs: ["libswscale", "libavutil"],
        preprocessor: Unifex
      ],
      converter: [
        interface: :nif,
        sources: ["pixel_format_converter/converter.c"],
        pkg_configs: ["libswscale", "libavutil"],
        preprocessor: Unifex
      ]
    ]
  end
end
