module Membrane.FFmpeg.SWScale.Scaler.Native

state_type "State"

spec create(
       input_width :: int,
       input_height :: int,
       output_width :: int,
       output_height :: int
     ) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec scale(payload, use_shm :: bool, state) ::
       {:ok :: label, payload} | {:error :: label, reason :: atom}

dirty :cpu, scale: 3
