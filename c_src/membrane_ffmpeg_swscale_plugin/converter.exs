module Membrane.FFmpeg.SWScale.Native
state_type "State"

spec do_create(
       old_width :: uint,
       old_height :: uint,
       old_format :: atom,
       new_width :: uint,
       new_height :: uint,
       new_format :: atom
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec process(state, payload) :: {:ok :: label, payload} | {:error :: label, reason :: atom}

interface [NIF]
