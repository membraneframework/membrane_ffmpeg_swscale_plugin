#pragma once

#include <libswscale/swscale.h>

typedef struct State
{
  struct SwsContext* sws_context;
  int width, height;
  enum AVPixelFormat srcFormat;
  enum AVPixelFormat dstFormat;
} State;

#include "_generated/converter.h"