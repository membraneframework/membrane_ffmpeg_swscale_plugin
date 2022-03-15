#include "converter.h"
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

enum AVPixelFormat string_to_AVPixelFormat(char *);

UNIFEX_TERM create(UnifexEnv *env, uint64_t width, uint64_t height,
                   char *old_format, char *new_format) {
  UNIFEX_TERM res;
  const enum AVPixelFormat input_fmt = string_to_AVPixelFormat(old_format),
                           output_fmt = string_to_AVPixelFormat(new_format);

  if (input_fmt == AV_PIX_FMT_NONE) {
    return create_result_error(env, "unknown_input_format");
  } else if (!sws_isSupportedInput(input_fmt)) {
    return create_result_error(env, "unsupported_input_format");
  }

  if (output_fmt == AV_PIX_FMT_NONE) {
    return create_result_error(env, "unknown_output_format");
  } else if (!sws_isSupportedOutput(output_fmt)) {
    return create_result_error(env, "unsupported_output_format");
  }

  State *state = unifex_alloc_state(env);
  state->sws_context =
      sws_getContext(width, height, input_fmt, width, height, output_fmt,
                     SWS_BICUBIC, NULL, NULL, NULL);

  if (state->sws_context == NULL) {
    res = create_result_error(env, "create_context_failed");
    goto end;
  }

  state->width = width;
  state->height = height;
  state->srcFormat = input_fmt;
  state->dstFormat = output_fmt;

  // Allocate memory for both the input and outputframes
  int src_image_size =
      av_image_alloc(state->src_data, state->src_linesize, state->width,
                     state->height, state->srcFormat, 1);
  state->dst_image_size =
      av_image_alloc(state->dst_data, state->dst_linesize, state->width,
                     state->height, state->dstFormat, 1);

  if (src_image_size < 0 || state->dst_image_size < 0) {
    sws_freeContext(state->sws_context);
    res = create_result_error(env, "memory_allocation_failed");
    goto end;
  }

  res = create_result_ok(env, state);
end:
  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM process(UnifexEnv *env, State *state, UnifexPayload *payload) {
  UNIFEX_TERM ret;

  // copy input to av_image
  av_image_fill_arrays(state->src_data, state->src_linesize, payload->data,
                       state->srcFormat, state->width, state->height, 1);

  // perform the conversion
  if (sws_scale(state->sws_context, (const uint8_t *const *)state->src_data,
                (const int *)state->src_linesize, 0, state->height,
                state->dst_data, state->dst_linesize) < 0) {
    ret = process_result_error(env, "scaling_failed");
    goto end;
  }

  UnifexPayload output_payload;
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, state->dst_image_size,
                       &output_payload);
  // copy output from av_frame to buffer
  if (av_image_copy_to_buffer(output_payload.data, state->dst_image_size,
                              (const uint8_t *const *)state->dst_data,
                              (const int *)state->dst_linesize,
                              state->dstFormat, state->width, state->height,
                              1) < 0) {
    ret = process_result_error(env, "copy_to_buffer_failed");
  } else {
    ret = process_result_ok(env, &output_payload);
  }
  unifex_payload_release(&output_payload);
end:
  return ret;
}

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);
  if (state->sws_context) {
    sws_freeContext(state->sws_context);
  }
}

enum AVPixelFormat string_to_AVPixelFormat(char *format) {
  if (strcmp(format, "I420") == 0) {
    return AV_PIX_FMT_YUV420P;
  } else if (strcmp(format, "I422") == 0) {
    return AV_PIX_FMT_YUV422P;
  } else if (strcmp(format, "I444") == 0) {
    return AV_PIX_FMT_YUV444P;
  } else if (strcmp(format, "RGB") == 0) {
    return AV_PIX_FMT_RGB24;
  } else if (strcmp(format, "RGBA") == 0) {
    return AV_PIX_FMT_RGBA;
  } else if (strcmp(format, "NV12") == 0) {
    return AV_PIX_FMT_NV12;
  } else if (strcmp(format, "NV21") == 0) {
    return AV_PIX_FMT_NV21;
  } else if (strcmp(format, "YV12") == 0) {
    return AV_PIX_FMT_YUVA420P;
  } else {
    return AV_PIX_FMT_NONE;
  }
}