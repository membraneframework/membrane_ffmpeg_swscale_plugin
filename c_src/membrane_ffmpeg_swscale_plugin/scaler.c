#include "scaler.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->sws_context != NULL) {
    sws_freeContext(state->sws_context);
  }

  av_freep(&state->input_data[0]);
  av_freep(&state->scaled_data[0]);
  av_freep(&state->output_data[0]);
}

void calculatate_scaling_resolution(int input_width, int input_height,
                                    int output_width, int output_height,
                                    int *scaled_width, int *scaled_height) {
  if ((float)(output_height * input_width / input_height) <= output_width) {
    // paddings on left and right

    *scaled_width = output_height * input_width / input_height;
    *scaled_height = output_height;

    // both paddings need even width
    *scaled_width = *scaled_width / 2 * 2;
    if ((output_width - *scaled_width) % 4 != 0)
      *scaled_width -= 2;

    // only even size
    *scaled_height = *scaled_height / 2 * 2;
  } else {
    // paddings above and below

    *scaled_width = output_width;
    *scaled_height = output_width * input_height / input_width;

    // only even size
    *scaled_width = *scaled_width / 2 * 2;

    // both paddings need even height
    *scaled_height = *scaled_height / 2 * 2;
    if ((output_height - *scaled_height) % 4 != 0)
      *scaled_height -= 2;
  }
}

UNIFEX_TERM create(UnifexEnv *env, int input_width, int input_height,
                   int output_width, int output_height) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  state->sws_context = NULL;

  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;
  int scaling_algorithm = SWS_BILINEAR;

  int scaled_width;
  int scaled_height;

  calculatate_scaling_resolution(input_width, input_height, output_width,
                                 output_height, &scaled_width, &scaled_height);

  state->input_width = input_width;
  state->input_height = input_height;

  state->output_width = output_width;
  state->output_height = output_height;

  state->scaled_width = scaled_width;
  state->scaled_height = scaled_height;

  state->sws_context = sws_getContext(input_width, input_height, pixel_format,
                                      scaled_width, scaled_height, pixel_format,
                                      scaling_algorithm, NULL, NULL, NULL);

  if (!state->sws_context) {
    result = create_result_error(env, "get_context");
    goto exit_create;
  }

  if (av_image_alloc(state->input_data, state->input_linesize, input_width,
                     input_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "input_alloc");
    goto exit_create;
  }

  if (av_image_alloc(state->scaled_data, state->scaled_linesize, scaled_width,
                     scaled_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "scaled_alloc");
    goto exit_create;
  }

  if (av_image_alloc(state->output_data, state->output_linesize, output_width,
                     output_height, pixel_format, 1) < 0) {
    result = create_result_error(env, "output_alloc");
    goto exit_create;
  }

  result = create_result_ok(env, state);

exit_create:
  unifex_release_state(env, state);
  return result;
}

void add_paddings(uint8_t *scaled_data[4], int scaled_width, int scaled_height,
                  uint8_t *dst_data[4], int output_width, int output_height) {
  if (scaled_height == output_height) {
    // paddings on left and right
    int start = (output_width - scaled_width) / 2;
    int end = start + scaled_width;

    for (int h = 0; h < output_height; h++) {
      for (int w = 0; w < output_width; w++) {
        if (w < start || w >= end)
          dst_data[0][h * output_width + w] = 0;
        else
          dst_data[0][h * output_width + w] =
              scaled_data[0][h * scaled_width + w - start];
      }
    }

    for (int h = 0; h < output_height / 2; h++) {
      for (int w = 0; w < output_width / 2; w++) {
        if (w < start / 2 || w >= end / 2) {
          dst_data[1][h * output_width / 2 + w] = 128;
          dst_data[2][h * output_width / 2 + w] = 128;
        } else {
          dst_data[1][h * output_width / 2 + w] =
              scaled_data[1][h * scaled_width / 2 + w - start / 2];
          dst_data[2][h * output_width / 2 + w] =
              scaled_data[2][h * scaled_width / 2 + w - start / 2];
        }
      }
    }
  } else {
    // paddings above and below
    int start = (output_height - scaled_height) / 2;
    int end = start + scaled_height;

    for (int h = 0; h < output_height; h++) {
      if (h < start || h >= end) {
        for (int w = 0; w < output_width; w++)
          dst_data[0][h * output_width + w] = 0;
      } else {
        for (int w = 0; w < output_width; w++)
          dst_data[0][h * output_width + w] =
              scaled_data[0][(h - start) * scaled_width + w];
      }
    }

    for (int h = 0; h < output_height / 2; h++) {
      if (h < start / 2 || h >= end / 2) {
        for (int w = 0; w < output_width; w++) {
          dst_data[1][h * output_width / 2 + w] = 128;
          dst_data[2][h * output_width / 2 + w] = 128;
        }
      } else {
        for (int w = 0; w < output_width; w++) {
          dst_data[1][h * output_width / 2 + w] =
              scaled_data[1][(h - start / 2) * scaled_width / 2 + w];
          dst_data[2][h * output_width / 2 + w] =
              scaled_data[2][(h - start / 2) * scaled_width / 2 + w];
        }
      }
    }
  }
}

UNIFEX_TERM scale(UnifexEnv *env, UnifexPayload *payload, State *state) {
  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;

  if (av_image_fill_arrays(state->input_data, state->input_linesize,
                           payload->data, pixel_format, state->input_width,
                           state->input_height, 1) < 0) {
    return scale_result_error(env, "fill_input");
  }

  sws_scale(state->sws_context, (const uint8_t *const *)state->input_data,
            state->input_linesize, 0, state->input_height, state->scaled_data,
            state->scaled_linesize);

  add_paddings(state->scaled_data, state->scaled_width, state->scaled_height,
               state->output_data, state->output_width, state->output_height);

  size_t payload_size = av_image_get_buffer_size(
      pixel_format, state->output_width, state->output_height, 1);
  UnifexPayload *frame =
      unifex_payload_alloc(env, UNIFEX_PAYLOAD_SHM, payload_size);

  if (av_image_copy_to_buffer(
          frame->data, payload_size, (const uint8_t *const *)state->output_data,
          (const int *)state->output_linesize, pixel_format,
          state->output_width, state->output_height, 1) < 0) {
    return scale_result_error(env, "copy_to_payload");
  }

  return scale_result_ok(env, frame);
}
