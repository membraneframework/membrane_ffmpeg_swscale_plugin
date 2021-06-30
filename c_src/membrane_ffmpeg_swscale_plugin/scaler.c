#include "scaler.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->sws_context != NULL) {
    sws_freeContext(state->sws_context);
  }

  for (int i = 0; i < 4; i++) {
    av_freep(&state->source_data[i]);
    av_freep(&state->scaled_data[i]);
    av_freep(&state->target_data[i]);
  }
}

void calculatate_scaling_resolution(int source_width, int source_height,
                                    int target_width, int target_height,
                                    int *scaled_width, int *scaled_height) {
  if ((float)(target_height * source_width / source_height) <= target_width) {
    // paddings on left and right

    *scaled_width = target_height * source_width / source_height;
    *scaled_height = target_height;

    // both paddings need even width
    *scaled_width = *scaled_width / 2 * 2;
    if ((target_width - *scaled_width) % 4 != 0)
      *scaled_width -= 2;

    // only even size
    *scaled_height = *scaled_height / 2 * 2;
  } else {
    // paddings above and below

    *scaled_width = target_width;
    *scaled_height = target_width * source_height / source_width;

    // only even size
    *scaled_width = *scaled_width / 2 * 2;

    // both paddings need even height
    *scaled_height = *scaled_height / 2 * 2;
    if ((target_height - *scaled_height) % 4 != 0)
      *scaled_height -= 2;
  }
}

UNIFEX_TERM create(UnifexEnv *env, int source_width, int source_height,
                   int target_width, int target_height) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  state->sws_context = NULL;

  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;
  int scaling_algorithm = SWS_BILINEAR;

  int scaled_width;
  int scaled_height;

  calculatate_scaling_resolution(source_width, source_height, target_width,
                                 target_height, &scaled_width, &scaled_height);

  state->source_width = source_width;
  state->source_height = source_height;

  state->target_width = target_width;
  state->target_height = target_height;

  state->scaled_width = scaled_width;
  state->scaled_height = scaled_height;

  state->sws_context = sws_getContext(source_width, source_height, pixel_format,
                                      scaled_width, scaled_height, pixel_format,
                                      scaling_algorithm, NULL, NULL, NULL);

  if (!state->sws_context) {
    result = create_result_error(env, "get_context");
    goto exit_create;
  }

  if (av_image_alloc(state->source_data, state->source_linesize, source_width,
                     source_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "source_alloc");
    goto exit_create;
  }

  if (av_image_alloc(state->scaled_data, state->scaled_linesize, scaled_width,
                     scaled_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "scaled_alloc");
    goto exit_create;
  }

  if (av_image_alloc(state->target_data, state->target_linesize, target_width,
                     target_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "target_alloc");
    goto exit_create;
  }

  result = create_result_ok(env, state);

exit_create:
  unifex_release_state(env, state);
  return result;
}

void add_paddings(uint8_t *scaled_data[4], int scaled_width, int scaled_height,
                  uint8_t *dst_data[4], int target_width, int target_height) {
  if (scaled_height == target_height) {
    // paddings on left and right
    int start = (target_width - scaled_width) / 2;
    int end = start + scaled_width;

    for (int h = 0; h < target_height; h++) {
      for (int w = 0; w < target_width; w++) {
        if (w < start || w >= end)
          dst_data[0][h * target_width + w] = 0;
        else
          dst_data[0][h * target_width + w] =
              scaled_data[0][h * scaled_width + w - start];
      }
    }

    for (int h = 0; h < target_height / 2; h++) {
      for (int w = 0; w < target_width / 2; w++) {
        if (w < start / 2 || w >= end / 2) {
          dst_data[1][h * target_width / 2 + w] = 128;
          dst_data[2][h * target_width / 2 + w] = 128;
        } else {
          dst_data[1][h * target_width / 2 + w] =
              scaled_data[1][h * scaled_width / 2 + w - start / 2];
          dst_data[2][h * target_width / 2 + w] =
              scaled_data[2][h * scaled_width / 2 + w - start / 2];
        }
      }
    }
  } else {
    // paddings above and below
    int start = (target_height - scaled_height) / 2;
    int end = start + scaled_height;

    for (int h = 0; h < target_height; h++) {
      if (h < start || h >= end) {
        for (int w = 0; w < target_width; w++)
          dst_data[0][h * target_width + w] = 0;
      } else {
        for (int w = 0; w < target_width; w++)
          dst_data[0][h * target_width + w] =
              scaled_data[0][(h - start) * scaled_width + w];
      }
    }

    for (int h = 0; h < target_height / 2; h++) {
      if (h < start / 2 || h >= end / 2) {
        for (int w = 0; w < target_width; w++) {
          dst_data[1][h * target_width / 2 + w] = 128;
          dst_data[2][h * target_width / 2 + w] = 128;
        }
      } else {
        for (int w = 0; w < target_width; w++) {
          dst_data[1][h * target_width / 2 + w] =
              scaled_data[1][(h - start / 2) * scaled_width / 2 + w];
          dst_data[2][h * target_width / 2 + w] =
              scaled_data[2][(h - start / 2) * scaled_width / 2 + w];
        }
      }
    }
  }
}

UNIFEX_TERM scale(UnifexEnv *env, UnifexPayload *payload, State *state) {
  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;

  if (av_image_fill_arrays(state->source_data, state->source_linesize,
                           payload->data, pixel_format, state->source_width,
                           state->source_height, 1) < 0) {
    return create_result_error(env, "fill_source");
  }

  sws_scale(state->sws_context, (const uint8_t *const *)state->source_data,
            state->source_linesize, 0, state->source_height, state->scaled_data,
            state->scaled_linesize);

  add_paddings(state->scaled_data, state->scaled_width, state->scaled_height,
               state->target_data, state->target_width, state->target_height);

  size_t payload_size = av_image_get_buffer_size(
      pixel_format, state->target_width, state->target_height, 1);
  UnifexPayload *frame =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_SHM, payload_size);

  if (av_image_copy_to_buffer(
          frame->data, payload_size, (const uint8_t *const *)state->target_data,
          (const int *)state->target_linesize, pixel_format,
          state->target_width, state->target_height, 1) < 0) {
    return create_result_error(env, "copy_to_payload");
  }

  return scale_result_ok(env, frame);
}
