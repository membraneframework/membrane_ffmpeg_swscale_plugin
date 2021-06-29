#include "scaler.h"

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);

  if (state->sws_context != NULL) {
    sws_freeContext(state->sws_context);
  }

  av_freep(&state->source_data[0]);
  av_freep(&state->scaled_data[0]);
  av_freep(&state->desired_data[0]);
}

void calculatate_scaling_resolution(int source_width, int source_height, int desired_width, int desired_height, int *scaled_width, int *scaled_height) {
  if ((float) (desired_height * source_width / source_height) <= desired_width) {
    // paddings on left and right
    *scaled_width = desired_height * source_width / source_height;
    *scaled_height = desired_height;

    // both paddings need even width
    *scaled_width = *scaled_width / 2 * 2;
    if ((desired_width - *scaled_width) % 4 != 0)
      *scaled_width -= 2;

    // only even size
    *scaled_height = *scaled_height / 2 * 2;
  } else {
    // paddings above and below
    *scaled_width = desired_width;
    *scaled_height = desired_width * source_height / source_width;

    // only even size
    *scaled_width = *scaled_width / 2 * 2;

    // both paddings need even height
    *scaled_height = *scaled_height / 2 * 2;
    if ((desired_height - *scaled_height) % 4 != 0)
      *scaled_height -= 2;
  }
}

UNIFEX_TERM create(UnifexEnv *env, int source_width, int source_height, int desired_width, int desired_height) {
  State *state = unifex_alloc_state(env);

  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;
  int ret;

  int scaled_width;
  int scaled_height;

  calculatate_scaling_resolution(source_width, source_height, desired_width, desired_height, &scaled_width, &scaled_height);

  printf("scaled resolution: %dx%d\n", scaled_width, scaled_height);

  state->source_width = source_width;
  state->source_height = source_height;

  state->desired_width = desired_width;
  state->desired_height = desired_height;

  state->scaled_width = scaled_width;
  state->scaled_height = scaled_height;

  state->sws_context = sws_getContext(source_width, source_height, pixel_format,
                            scaled_width, scaled_height, pixel_format,
                            SWS_BILINEAR, NULL, NULL, NULL);

  if (!state->sws_context) {
    fprintf(stderr,
            "Impossible to create scale context for the conversion "
            "fmt:%s s:%dx%d -> fmt:%s s:%dx%d\n",
            av_get_pix_fmt_name(pixel_format), source_width, source_height,
            av_get_pix_fmt_name(pixel_format), scaled_width, scaled_height);
    ret = AVERROR(EINVAL);
    return create_result_error(env, "create");
  }

  if ((ret = av_image_alloc(state->source_data, state->source_linesize,
                            source_width, source_height, pixel_format, 1)) < 0) {
    fprintf(stderr, "Could not allocate source image\n");
    return create_result_error(env, "alloc source data");
  }

  if ((ret = av_image_alloc(state->scaled_data, state->scaled_linesize,
                            scaled_width, scaled_height, pixel_format, 1)) < 0) {
    fprintf(stderr, "Could not allocate scaled image\n");
    return create_result_error(env, "alloc scaled data");
  }

  if ((ret = av_image_alloc(state->desired_data, state->desired_linesize,
                            desired_width, desired_height, pixel_format, 1)) < 0) {
    fprintf(stderr, "Could not allocate destination image\n");
    return create_result_error(env, "alloc desired data");
  }

  return create_result_ok(env, state);
}

void add_paddings(uint8_t *scaled_data[4], int scaled_width, int scaled_height, 
                  uint8_t *dst_data[4], int desired_width, int desired_height) {

  if (scaled_height == desired_height) {
    // paddings on left and right
    int start = (desired_width - scaled_width) / 2;
    int end = start + scaled_width;

    for (int h=0; h < desired_height; h++) {
      for (int w=0; w < desired_width; w++) {
        if (w < start || w >= end)
          dst_data[0][h * desired_width + w] = 0;
        else
          dst_data[0][h * desired_width + w] = scaled_data[0][h * scaled_width + w - start];
      }
    }

    for (int h=0; h < desired_height / 2; h++) {
      for (int w=0; w < desired_width / 2; w++) {
        if (w < start / 2 || w >= end / 2) {
          dst_data[1][h * desired_width / 2 + w] = 128;
          dst_data[2][h * desired_width / 2 + w] = 128;
        }
        else {
          dst_data[1][h * desired_width / 2 + w] = scaled_data[1][h * scaled_width / 2 + w - start / 2];
          dst_data[2][h * desired_width / 2 + w] = scaled_data[2][h * scaled_width / 2 + w - start / 2];
        }
      }
    }
  } else {
    // paddings above and below
    int start = (desired_height - scaled_height) / 2;
    int end = start + scaled_height;

    for (int h=0; h < desired_height; h++) {
      if (h < start || h >= end) {
        for (int w=0; w < desired_width; w++)
          dst_data[0][h * desired_width + w] = 0;
      } else {
        for (int w=0; w < desired_width; w++)
          dst_data[0][h * desired_width + w] = scaled_data[0][(h - start) * scaled_width + w];
      }
    }

    for (int h=0; h < desired_height / 2; h++) {
      if (h < start / 2 || h >= end / 2) {
        for (int w=0; w < desired_width; w++) {
          dst_data[1][h * desired_width / 2 + w] = 128;
          dst_data[2][h * desired_width / 2 + w] = 128;
        }
      } else {
        for (int w=0; w < desired_width; w++) {
          dst_data[1][h * desired_width / 2 + w] = scaled_data[1][(h - start / 2) * scaled_width / 2 + w];
          dst_data[2][h * desired_width / 2 + w] = scaled_data[2][(h - start / 2) * scaled_width / 2 + w];
        }
      }
    }
  }
}

UNIFEX_TERM scale(UnifexEnv *env, UnifexPayload *payload, State *state) {
  enum AVPixelFormat pixel_format = AV_PIX_FMT_YUV420P;

  av_image_fill_arrays(state->source_data, state->source_linesize, payload->data,
                       pixel_format, state->source_width, state->source_height, 1);

  sws_scale(state->sws_context, (const uint8_t * const*)state->source_data,
              state->source_linesize, 0, state->source_height, state->scaled_data, state->scaled_linesize);
    
  add_paddings(state->scaled_data, state->scaled_width, state->scaled_height, state->desired_data, state->desired_width, state->desired_height);

  size_t payload_size = av_image_get_buffer_size(pixel_format, state->desired_width, state->desired_height, 1);
  UnifexPayload *frame = unifex_payload_alloc(env, UNIFEX_PAYLOAD_SHM, payload_size);
  
  av_image_copy_to_buffer(
        frame->data, payload_size,
        (const uint8_t *const *)state->desired_data, (const int *)state->desired_linesize,
        pixel_format, state->desired_width, state->desired_height, 1
  );

  return scale_result_ok(env, frame);
}
