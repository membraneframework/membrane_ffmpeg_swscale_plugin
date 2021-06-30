module Membrane.FFmpeg.SWScale.Scaler.Native

state_type "State"

spec create(
    source_width :: int,
    source_height :: int,
    target_width :: int,
    target_height :: int
) :: {:ok :: label, state} | {:error :: label, reason :: atom}

spec scale(payload, state) :: {:ok :: label, payload} | {:error :: label, reason :: atom}