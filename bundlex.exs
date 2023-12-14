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
        os_deps: [
          ffmpeg: [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:ffmpeg),
             ["libswscale", "libavutil"]},
            {:pkg_config, ["libswscale", "libavutil"]}
          ]
        ],
        preprocessor: Unifex
      ],
      converter: [
        interface: :nif,
        sources: ["pixel_format_converter/converter.c"],
        os_deps: [
          ffmpeg: [
            {:precompiled, Membrane.PrecompiledDependencyProvider.get_dependency_url(:ffmpeg),
             ["libswscale", "libavutil"]},
            {:pkg_config, ["libswscale", "libavutil"]}
          ]
        ],
        preprocessor: Unifex
      ]
    ]
  end
end
