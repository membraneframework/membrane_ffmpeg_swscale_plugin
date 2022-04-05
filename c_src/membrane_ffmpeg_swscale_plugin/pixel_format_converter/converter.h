#pragma once

#include <libswscale/swscale.h>

typedef struct State {
  struct SwsContext *sws_context;
  int width, height;
  enum AVPixelFormat src_format, dst_format;

  uint8_t *src_data[4], *dst_data[4];
  int src_linesize[4], dst_linesize[4];

  int dst_image_size;
} State;

#include "_generated/converter.h"
