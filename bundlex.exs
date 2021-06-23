defmodule Membrane.FFmpeg.SWScale.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives(Bundlex.platform())
    ]
  end

  defp natives(_platform) do
    [
      scaler: [
        sources: ["scaler.c"],
        deps: [unifex: :unifex],
        interface: [:nif, :cnode],
        preprocessor: Unifex
      ]
    ]
  end
end
