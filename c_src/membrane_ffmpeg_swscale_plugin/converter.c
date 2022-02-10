#include "converter.h"
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>

enum AVPixelFormat string_to_format(char *);

UNIFEX_TERM create(UnifexEnv *env, unsigned int width, unsigned int height,
                      char *old_format, char *new_format) {
  const enum AVPixelFormat input_fmt = string_to_format(old_format),
                           output_fmt = string_to_format(new_format);

  if (input_fmt == AV_PIX_FMT_NONE) {
    return create_result_error(env, "invalid_input_format");
  } else if (!sws_isSupportedInput(input_fmt)) {
    return create_result_error(env, "unsupported_input_format");
  }

  if (output_fmt == AV_PIX_FMT_NONE) {
    return create_result_error(env, "invalid_output_format");
  } else if (!sws_isSupportedOutput(output_fmt)) {
    return create_result_error(env, "unsupported_output_format");
  }

  State *state = unifex_alloc_state(env);
  state->sws_context =
      sws_getContext(width, height, input_fmt, width, height,
                     output_fmt, SWS_BICUBIC, NULL, NULL, NULL);
  state->width = width;
  state->height = height;
  state->srcFormat = input_fmt;
  UNIFEX_TERM res;

  if (state->sws_context == NULL) {
    res = create_result_error(env, "unable_to_create_context");
  } else {
    res = create_result_ok(env, state);
  }

  unifex_release_state(env, state);
  return res;
}

UNIFEX_TERM process(UnifexEnv *env, State *state, UnifexPayload *payload) {
  uint8_t *src_data[4], *dst_data[4];
  int src_linesize[4], dst_linesize[4];

  UNIFEX_TERM ret;

  av_image_alloc(src_data, src_linesize, state->width, state->height,
                 state->srcFormat, 16);
  int dst_image_size = av_image_alloc(dst_data, dst_linesize, state->width,
                                      state->height, state->dstFormat, 1);
  av_image_fill_arrays(src_data, src_linesize, payload->data, state->srcFormat,
                       state->width, state->height, 16);

  if (dst_image_size < 0) {
    ret = process_result_error(env, "unable_to_allocate_output_image");
    goto end;
  }

  int scaling_result =
      sws_scale(state->sws_context, (const uint8_t *const *)src_data,
                src_linesize, 0, state->height, dst_data, dst_linesize);
  if (scaling_result < 0) {
    char *error = malloc(100);
    fprintf(stderr, "Error while scaling: %s\n",
            av_make_error_string(error, 100, scaling_result));
    ret = process_result_error(env, "scaling_failed");
    free(error);
    goto end;
  }

  UnifexPayload output_payload;
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, dst_image_size,
                       &output_payload);
  memcpy(output_payload.data, dst_data[0], dst_image_size);
  ret = process_result_ok(env, &output_payload);
  unifex_payload_release(&output_payload);
end:
  return ret;
}

void handle_destroy_state(UnifexEnv *_env, State *state) {
  if (state->sws_context) {
    sws_freeContext(state->sws_context);
  }
}

enum AVPixelFormat string_to_format(char *string) {
  if (strcmp(string, "I420") == 0) {
    return AV_PIX_FMT_YUV420P;
  } else if (strcmp(string, "I422") == 0) {
    return AV_PIX_FMT_YUV422P;
  } else if (strcmp(string, "I444") == 0) {
    return AV_PIX_FMT_YUV444P;
  } else if (strcmp(string, "RGB") == 0) {
    return AV_PIX_FMT_RGB24;
  } else if (strcmp(string, "RGBA") == 0) {
    return AV_PIX_FMT_RGBA;
  } else if (strcmp(string, "NV12") == 0) {
    return AV_PIX_FMT_NV12;
  } else if (strcmp(string, "NV21") == 0) {
    return AV_PIX_FMT_NV21;
  } else if (strcmp(string, "YV12") == 0) {
    return AV_PIX_FMT_YUVA420P;
  } else {
    return AV_PIX_FMT_NONE;
  }
}