#pragma once

#include <stdio.h>
#include <libavutil/imgutils.h>
#include <libavutil/parseutils.h>
#include <libswscale/swscale.h>

typedef struct ScalerState {  
  int source_width;
  int source_height;
  
  int desired_width;
  int desired_height;

  int scaled_width;
  int scaled_height;

  struct SwsContext *sws_context;

  uint8_t *source_data[4], *scaled_data[4], *desired_data[4];
  int source_linesize[4], scaled_linesize[4], desired_linesize[4];
} State;

#include "_generated/scaler.h"