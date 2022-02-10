#pragma once

#include <libswscale/swscale.h>

typedef struct State
{
  struct SwsContext* sws_context;
  int srcWidth, srcHeight;
  enum AVPixelFormat srcFormat;
  enum AVPixelFormat dstFormat;
} State;

#include "_generated/converter.h"