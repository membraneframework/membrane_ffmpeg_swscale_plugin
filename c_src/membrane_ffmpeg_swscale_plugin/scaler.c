#include <stdio.h>
#include <libavutil/imgutils.h>
#include <libavutil/parseutils.h>
#include <libswscale/swscale.h>

void calculatate_scaling_resolution(int src_w, int src_h, int dst_w, int dst_h, int *scaled_w, int *scaled_h) {
  if ((float) (dst_h * src_w / src_h) <= dst_w) {
    // paddings on left and right
    *scaled_w = dst_h * src_w / src_h;
    *scaled_h = dst_h;

    // both paddings need even width
    *scaled_w = *scaled_w / 2 * 2;
    if ((dst_w - *scaled_w) % 4 != 0)
      *scaled_w -= 2;

    // only even size
    *scaled_h = *scaled_h / 2 * 2;
  } else {
    // paddings above and below
    *scaled_w = dst_w;
    *scaled_h = dst_w * src_h / src_w;

    // only even size
    *scaled_w = *scaled_w / 2 * 2;

    // both paddings need even height
    *scaled_h = *scaled_h / 2 * 2;
    if ((dst_h - *scaled_h) % 4 != 0)
      *scaled_h -= 2;
  }
}
 
int read_from_file(uint8_t *data[4], int height, int linesize[4], FILE *file) {
  fread(data[0], 1, height * linesize[0], file);
  fread(data[1], 1, height / 2 * linesize[1], file);
  fread(data[2], 1, height / 2 * linesize[2], file);

  if (feof(file)) return -1;
  return 0;
}

void add_paddings(uint8_t *scaled_data[4], int scaled_w, int scaled_h, 
                  uint8_t *dst_data[4], int dst_w, int dst_h) {

  if (scaled_h == dst_h) {
    // paddings on left and right
    int start = (dst_w - scaled_w) / 2;
    int end = start + scaled_w;

    for (int h=0; h < dst_h; h++) {
      for (int w=0; w < dst_w; w++) {
        if (w < start || w >= end)
          dst_data[0][h * dst_w + w] = 0;
        else
          dst_data[0][h * dst_w + w] = scaled_data[0][h * scaled_w + w - start];
      }
    }

    for (int h=0; h < dst_h / 2; h++) {
      for (int w=0; w < dst_w / 2; w++) {
        if (w < start / 2 || w >= end / 2) {
          dst_data[1][h * dst_w / 2 + w] = 128;
          dst_data[2][h * dst_w / 2 + w] = 128;
        }
        else {
          dst_data[1][h * dst_w / 2 + w] = scaled_data[1][h * scaled_w / 2 + w - start / 2];
          dst_data[2][h * dst_w / 2 + w] = scaled_data[2][h * scaled_w / 2 + w - start / 2];
        }
      }
    }
  } else {
    // paddings above and below
    int start = (dst_h - scaled_h) / 2;
    int end = start + scaled_h;

    for (int h=0; h < dst_h; h++) {
      if (h < start || h >= end) {
        for (int w=0; w < dst_w; w++)
          dst_data[0][h * dst_w + w] = 0;
      } else {
        for (int w=0; w < dst_w; w++)
          dst_data[0][h * dst_w + w] = scaled_data[0][(h - start) * scaled_w + w];
      }
    }

    for (int h=0; h < dst_h / 2; h++) {
      if (h < start / 2 || h >= end / 2) {
        for (int w=0; w < dst_w; w++) {
          dst_data[1][h * dst_w / 2 + w] = 128;
          dst_data[2][h * dst_w / 2 + w] = 128;
        }
      } else {
        for (int w=0; w < dst_w; w++) {
          dst_data[1][h * dst_w / 2 + w] = scaled_data[1][(h - start / 2) * scaled_w / 2 + w];
          dst_data[2][h * dst_w / 2 + w] = scaled_data[2][(h - start / 2) * scaled_w / 2 + w];
        }
      }
    }
  }
}

void save_to_file(uint8_t *data[4], int height, int linesize[4], FILE *file) {
  fwrite(data[0], 1, height * linesize[0], file);
  fwrite(data[1], 1, height / 2 * linesize[1], file);
  fwrite(data[2], 1, height / 2 * linesize[2], file);
}

int main(int argc, char **argv) {
  uint8_t *src_data[4], *scaled_data[4], *dst_data[4];
  int src_linesize[4], scaled_linesize[4], dst_linesize[4];
  enum AVPixelFormat pix_fmt = AV_PIX_FMT_YUV420P;
  struct SwsContext *sws_ctx;
  int i, ret;

  int src_w = 360;
  int src_h = 640;
  
  int dst_w = 200;
  int dst_h = 750;

  int scaled_w;
  int scaled_h;

  calculatate_scaling_resolution(src_w, src_h, dst_w, dst_h, &scaled_w, &scaled_h);

  printf("scaled resolution: %dx%d\n", scaled_w, scaled_h);

  const char *src_filename = "1.yuv";
  const char *dst_filename = "2.yuv";

  sws_ctx = sws_getContext(src_w, src_h, pix_fmt,
                            scaled_w, scaled_h, pix_fmt,
                            SWS_BILINEAR, NULL, NULL, NULL);
  if (!sws_ctx) {
    fprintf(stderr,
            "Impossible to create scale context for the conversion "
            "fmt:%s s:%dx%d -> fmt:%s s:%dx%d\n",
            av_get_pix_fmt_name(pix_fmt), src_w, src_h,
            av_get_pix_fmt_name(pix_fmt), scaled_w, scaled_h);
    ret = AVERROR(EINVAL);
    goto end;
  }

  if ((ret = av_image_alloc(src_data, src_linesize,
                            src_w, src_h, pix_fmt, 1)) < 0) {
    fprintf(stderr, "Could not allocate source image\n");
    goto end;
  }

  if ((ret = av_image_alloc(scaled_data, scaled_linesize,
                            scaled_w, scaled_h, pix_fmt, 1)) < 0) {
    fprintf(stderr, "Could not allocate scaled image\n");
    goto end;
  }

  if ((ret = av_image_alloc(dst_data, dst_linesize,
                            dst_w, dst_h, pix_fmt, 1)) < 0) {
    fprintf(stderr, "Could not allocate destination image\n");
    goto end;
  }

  FILE *src_file = fopen(src_filename, "rb");
  if (!src_file) {
    fprintf(stderr, "Could not open source file %s\n", src_filename);
    exit(1);
  }

  FILE *dst_file = fopen(dst_filename, "wb");
  if (!dst_file) {
    fprintf(stderr, "Could not open destination file %s\n", dst_filename);
    exit(1);
  }

  int continue_reading = 0;
  while(1) {
    continue_reading = read_from_file(src_data, src_h, src_linesize, src_file);
    if (continue_reading < 0) break;

    sws_scale(sws_ctx, (const uint8_t * const*)src_data,
              src_linesize, 0, src_h, scaled_data, scaled_linesize);
    
    add_paddings(scaled_data, scaled_w, scaled_h, dst_data, dst_w, dst_h);

    // save_to_file(scaled_data, scaled_h, scaled_linesize, dst_file);
    save_to_file(dst_data, dst_h, dst_linesize, dst_file);
  }
 
end:
  fclose(src_file);
  fclose(dst_file);
  av_freep(&src_data[0]);
  av_freep(&dst_data[0]);
  sws_freeContext(sws_ctx);
  return ret < 0;
}