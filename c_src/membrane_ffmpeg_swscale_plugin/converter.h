#pragma once

#include <libswscale/swscale.h>

typedef struct State
{
  struct SwsContext* sws_context;
  int width, height;
  enum AVPixelFormat srcFormat;
  enum AVPixelFormat dstFormat;

  // Scaling buffers for 
  uint8_t *src_data[4], *dst_data[4];
  int src_linesize[4], dst_linesize[4];
  
  int dst_image_size;
} State;

#include "_generated/converter.h"