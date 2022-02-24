module Membrane.FFmpeg.SWScale.PixelFormatConverter.Native
state_type "State"

spec create(width :: uint64, height :: uint64, old_format :: atom, new_format :: atom) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec process(state, payload) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

interface [NIF]
