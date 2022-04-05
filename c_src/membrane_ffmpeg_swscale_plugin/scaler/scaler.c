#include "scaler.h"

#define BLACK_Y 0
#define BLACK_U 128
#define BLACK_V 128

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->sws_context != NULL) {
    sws_freeContext(state->sws_context);
  }

  av_freep(&state->scaled_data[0]);
  av_freep(&state->output_data[0]);
}

void calculate_scaling_resolution(int input_width, int input_height,
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

  calculate_scaling_resolution(input_width, input_height, output_width,
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
                  uint8_t *output_data[4], int output_width,
                  int output_height) {
  if (scaled_height == output_height) {
    // paddings on left and right
    int start = (output_width - scaled_width) / 2;
    int end = start + scaled_width;

    // luminance component (Y')
    for (int h = 0; h < output_height; h++) {
      for (int w = 0; w < output_width; w++) {
        int output_position = h * output_width + w;

        if (w < start || w >= end)
          output_data[0][output_position] = BLACK_Y;
        else
          output_data[0][output_position] =
              scaled_data[0][h * scaled_width + w - start];
      }
    }

    // chrominance components (U and V)
    for (int h = 0; h < output_height / 2; h++) {
      for (int w = 0; w < output_width / 2; w++) {
        int output_position = h * output_width / 2 + w;

        if (w < start / 2 || w >= end / 2) {
          output_data[1][output_position] = BLACK_U;
          output_data[2][output_position] = BLACK_V;
        } else {
          int scaled_position = h * scaled_width / 2 + w - start / 2;

          output_data[1][output_position] = scaled_data[1][scaled_position];
          output_data[2][output_position] = scaled_data[2][scaled_position];
        }
      }
    }
  } else {
    // paddings above and below
    int start = (output_height - scaled_height) / 2;
    int end = start + scaled_height;

    // luminance component (Y')
    for (int h = 0; h < output_height; h++) {
      for (int w = 0; w < output_width; w++) {
        int output_position = h * output_width + w;

        if (h < start || h >= end) {
          output_data[0][output_position] = BLACK_Y;
        } else {
          output_data[0][output_position] =
              scaled_data[0][(h - start) * scaled_width + w];
        }
      }
    }

    // chrominance components (U and V)
    for (int h = 0; h < output_height / 2; h++) {
      for (int w = 0; w < output_width / 2; w++) {
        int output_position = h * output_width / 2 + w;

        if (h < start / 2 || h >= end / 2) {
          output_data[1][output_position] = BLACK_U;
          output_data[2][output_position] = BLACK_V;
        } else {
          int scaled_position = (h - start / 2) * scaled_width / 2 + w;

          output_data[1][output_position] = scaled_data[1][scaled_position];
          output_data[2][output_position] = scaled_data[2][scaled_position];
        }
      }
    }
  }
}

UNIFEX_TERM scale(UnifexEnv *env, UnifexPayload *payload, int use_shm,
                  State *state) {
  UNIFEX_TERM res;

  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;

  uint8_t *input_data[4];
  int input_linesize[4];

  if (av_image_fill_arrays(input_data, input_linesize, payload->data,
                           pixel_format, state->input_width,
                           state->input_height, 1) < 0) {
    return scale_result_error(env, "fill_input");
  }

  sws_scale(state->sws_context, (const uint8_t *const *)input_data,
            input_linesize, 0, state->input_height, state->scaled_data,
            state->scaled_linesize);

  add_paddings(state->scaled_data, state->scaled_width, state->scaled_height,
               state->output_data, state->output_width, state->output_height);

  size_t payload_size = av_image_get_buffer_size(
      pixel_format, state->output_width, state->output_height, 1);

  UnifexPayload frame;
  UnifexPayloadType payload_type;
  if (use_shm) {
    payload_type = UNIFEX_PAYLOAD_SHM;
  } else {
    payload_type = UNIFEX_PAYLOAD_BINARY;
  }
  unifex_payload_alloc(env, payload_type, payload_size, &frame);

  if (av_image_copy_to_buffer(
          frame.data, payload_size, (const uint8_t *const *)state->output_data,
          (const int *)state->output_linesize, pixel_format,
          state->output_width, state->output_height, 1) < 0) {
    res = scale_result_error(env, "copy_to_payload");
    goto cleanup;
  }
  res = scale_result_ok(env, &frame);
cleanup:
  unifex_payload_release(&frame);
  return res;
}
