#ifndef AVCODEC_FFMETRIC_H
#define AVCODEC_FFMETRIC_H

typedef struct FFMetricContext {
    int i_count;
    int p_count;
    int b_count;

    double i_avg_qp;
    double p_avg_qp;
    double b_avg_qp;

    int i_size;
    int p_size;
    int b_size;

    double consecutive_bframes[4];

    double mb_i[3];

    double mb_p_i[3];
    double mb_p_p[5];
    double mb_p_skip;

    double mb_b_i[3];
    double mb_b_b[3];
    double mb_b_direct;
    double mb_b_skip;
    double mb_b_l0;
    double mb_b_l1;
    double mb_b_bi;

    double transform_8x8_intra;
    double transform_8x8_inter;

    double coded_intra[3];
    double coded_inter[3];

    double i16[4];
    double i8[9];
    double i4[9];
    double i8c[4];

    double weighted_p_y;
    double weighted_p_uv;

    double ref_p_l0[16];
    double ref_b_l0[16];
    double ref_b_l1[16];

    int ref_p_l0_count;
    int ref_b_l0_count;
    int ref_b_l1_count;

    double output_bitrate_kbps;

    int has_i;
    int has_p;
    int has_b;

    int x264_rc_is_crf;
    double x264_crf;
} FFMetricContext;

void ffmetric_reset(FFMetricContext *ctx);

void ffmetric_parse_x264_log(
    FFMetricContext *ctx,
    const char *line);

double ffmetric_predict(
    const FFMetricContext *ctx);

#endif
