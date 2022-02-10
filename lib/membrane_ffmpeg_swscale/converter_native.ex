defmodule Membrane.FFmpeg.SWScale.Native do
  @moduledoc false
  use Unifex.Loader

  alias Membrane.Caps.Video.Raw

  @spec create(Raw.t(), Raw.t()) :: {:ok, binary()} | {:error, reason :: atom()}
  def create(%Raw{} = old, %Raw{} = new),
    do: do_create(old.width, old.height, old.format, new.width, new.height, new.format)
end
