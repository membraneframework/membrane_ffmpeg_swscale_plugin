#pragma once

#include <libavutil/imgutils.h>
#include <libavutil/parseutils.h>
#include <libswscale/swscale.h>
#include <stdio.h>

typedef struct ScalerState {
  int input_width;
  int input_height;

  int output_width;
  int output_height;

  int scaled_width;
  int scaled_height;

  struct SwsContext *sws_context;

  uint8_t *scaled_data[4], *output_data[4];
  int scaled_linesize[4], output_linesize[4];
} State;

#include "_generated/scaler.h"
