module Membrane.FFmpeg.SWScale.PixFmtConverter.Native
state_type "State"

spec create( width :: uint, height :: uint, old_format :: atom, new_format :: atom) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec process(state, payload) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

interface [NIF]
