#include "ffmetric.h"
#include "ffmetric_xgb_model.h"

#include <stdio.h>
#include <string.h>

void ffmetric_reset(FFMetricContext *ctx)
{
    if (!ctx)
        return;

    memset(ctx, 0, sizeof(*ctx));
}

static int ffmetric_parse_percent_list(const char *p, double *values, int max_values)
{
    int count = 0;
    int consumed = 0;
    double value;

    while (count < max_values &&
           sscanf(p, " %lf%% %n", &value, &consumed) == 1) {
        values[count++] = value;
        p += consumed;
    }

    return count;
}

void ffmetric_parse_x264_log(FFMetricContext *ctx, const char *line)
{
    char frame_type;
    int count;
    double avg_qp;
    int size;

    if (!ctx || !line)
        return;

    if (sscanf(line, "frame %c:%d%*[^0-9.]%lf%*[^0-9]%d",
               &frame_type, &count, &avg_qp, &size) == 4) {
        switch (frame_type) {
        case 'I':
            ctx->i_count = count;
            ctx->i_avg_qp = avg_qp;
            ctx->i_size = size;
            ctx->has_i = 1;
            break;

        case 'P':
            ctx->p_count = count;
            ctx->p_avg_qp = avg_qp;
            ctx->p_size = size;
            ctx->has_p = 1;
            break;

        case 'B':
            ctx->b_count = count;
            ctx->b_avg_qp = avg_qp;
            ctx->b_size = size;
            ctx->has_b = 1;
            break;
        }

    } else if (!strncmp(line, "consecutive B-frames:", 21)) {
        ffmetric_parse_percent_list(line + 21,
                                    ctx->consecutive_bframes,
                                    4);

    } else if (!strncmp(line, "mb I", 4)) {
        const char *i16 = strstr(line, "I16..4:");

        if (i16)
            ffmetric_parse_percent_list(i16 + strlen("I16..4:"),
                                        ctx->mb_i,
                                        3);

    } else if (!strncmp(line, "mb P", 4)) {
        const char *i16 = strstr(line, "I16..4:");
        const char *p16 = strstr(line, "P16..4:");
        const char *skip = strstr(line, "skip:");

        if (i16)
            ffmetric_parse_percent_list(i16 + strlen("I16..4:"),
                                        ctx->mb_p_i,
                                        3);

        if (p16)
            ffmetric_parse_percent_list(p16 + strlen("P16..4:"),
                                        ctx->mb_p_p,
                                        5);

        if (skip)
            sscanf(skip, "skip: %lf%%", &ctx->mb_p_skip);

    } else if (!strncmp(line, "mb B", 4)) {
        const char *i16 = strstr(line, "I16..4:");
        const char *b16 = strstr(line, "B16..8:");
        const char *direct = strstr(line, "direct:");
        const char *skip = strstr(line, "skip:");
        const char *l0 = strstr(line, "L0:");
        const char *l1 = strstr(line, "L1:");
        const char *bi = strstr(line, "BI:");

        if (i16)
            ffmetric_parse_percent_list(i16 + strlen("I16..4:"),
                                        ctx->mb_b_i,
                                        3);

        if (b16)
            ffmetric_parse_percent_list(b16 + strlen("B16..8:"),
                                        ctx->mb_b_b,
                                        3);

        if (direct)
            sscanf(direct, "direct: %lf%%", &ctx->mb_b_direct);

        if (skip)
            sscanf(skip, "skip: %lf%%", &ctx->mb_b_skip);

        if (l0)
            sscanf(l0, "L0: %lf%%", &ctx->mb_b_l0);

        if (l1)
            sscanf(l1, "L1: %lf%%", &ctx->mb_b_l1);

        if (bi)
            sscanf(bi, "BI: %lf%%", &ctx->mb_b_bi);

    } else if (!strncmp(line, "8x8 transform", 13)) {
        sscanf(line,
               "8x8 transform intra:%lf%% inter:%lf%%",
               &ctx->transform_8x8_intra,
               &ctx->transform_8x8_inter);

    } else if (!strncmp(line, "coded y,uvDC,uvAC", 17)) {
        sscanf(line,
               "coded y,uvDC,uvAC intra: %lf%% %lf%% %lf%% inter: %lf%% %lf%% %lf%%",
               &ctx->coded_intra[0],
               &ctx->coded_intra[1],
               &ctx->coded_intra[2],
               &ctx->coded_inter[0],
               &ctx->coded_inter[1],
               &ctx->coded_inter[2]);

    } else if (!strncmp(line, "i16 v,h,dc,p:", 13)) {
        ffmetric_parse_percent_list(line + 13,
                                    ctx->i16,
                                    4);

    } else if (!strncmp(line, "i8 ", 3)) {
        const char *p = strchr(line, ':');

        if (p)
            ffmetric_parse_percent_list(p + 1,
                                        ctx->i8,
                                        9);

    } else if (!strncmp(line, "i4 ", 3)) {
        const char *p = strchr(line, ':');

        if (p)
            ffmetric_parse_percent_list(p + 1,
                                        ctx->i4,
                                        9);

    } else if (!strncmp(line, "i8c dc,h,v,p:", 13)) {
        ffmetric_parse_percent_list(line + 13,
                                    ctx->i8c,
                                    4);

    } else if (!strncmp(line, "Weighted P-Frames:", 18)) {
        sscanf(line,
               "Weighted P-Frames: Y:%lf%% UV:%lf%%",
               &ctx->weighted_p_y,
               &ctx->weighted_p_uv);

    } else if (!strncmp(line, "ref P L0:", 9)) {
        ctx->ref_p_l0_count =
            ffmetric_parse_percent_list(line + 9,
                                        ctx->ref_p_l0,
                                        16);

    } else if (!strncmp(line, "ref B L0:", 9)) {
        ctx->ref_b_l0_count =
            ffmetric_parse_percent_list(line + 9,
                                        ctx->ref_b_l0,
                                        16);

    } else if (!strncmp(line, "ref B L1:", 9)) {
        ctx->ref_b_l1_count =
            ffmetric_parse_percent_list(line + 9,
                                        ctx->ref_b_l1,
                                        16);

    } else if (!strncmp(line, "kb/s:", 5)) {
        sscanf(line,
               "kb/s:%lf",
               &ctx->output_bitrate_kbps);
    }
}

static void ffmetric_fill_features(const FFMetricContext *ctx, double *f)
{
    f[0]  = ctx->output_bitrate_kbps;

    f[1]  = ctx->i_count;
    f[2]  = ctx->i_avg_qp;
    f[3]  = ctx->i_size;

    f[4]  = ctx->p_count;
    f[5]  = ctx->p_avg_qp;
    f[6]  = ctx->p_size;

    f[7]  = ctx->b_count;
    f[8]  = ctx->b_avg_qp;
    f[9]  = ctx->b_size;

    f[10] = ctx->consecutive_bframes[0];
    f[11] = ctx->consecutive_bframes[1];
    f[12] = ctx->consecutive_bframes[2];
    f[13] = ctx->consecutive_bframes[3];

    f[14] = ctx->mb_i[0];
    f[15] = ctx->mb_i[1];
    f[16] = ctx->mb_i[2];

    f[17] = ctx->mb_p_i[0];
    f[18] = ctx->mb_p_i[1];
    f[19] = ctx->mb_p_i[2];

    f[20] = ctx->mb_p_p[0];
    f[21] = ctx->mb_p_p[1];
    f[22] = ctx->mb_p_p[2];
    f[23] = ctx->mb_p_skip;

    f[24] = ctx->mb_b_i[0];
    f[25] = ctx->mb_b_i[1];
    f[26] = ctx->mb_b_i[2];

    f[27] = ctx->mb_b_b[0];
    f[28] = ctx->mb_b_b[1];
    f[29] = ctx->mb_b_b[2];

    f[30] = ctx->mb_b_direct;
    f[31] = ctx->mb_b_skip;
    f[32] = ctx->mb_b_l0;
    f[33] = ctx->mb_b_l1;
    f[34] = ctx->mb_b_bi;

    f[35] = ctx->transform_8x8_intra;
    f[36] = ctx->transform_8x8_inter;

    f[37] = ctx->coded_intra[0];
    f[38] = ctx->coded_intra[1];
    f[39] = ctx->coded_intra[2];

    f[40] = ctx->coded_inter[0];
    f[41] = ctx->coded_inter[1];
    f[42] = ctx->coded_inter[2];

    f[43] = ctx->i16[0];
    f[44] = ctx->i16[1];
    f[45] = ctx->i16[2];
    f[46] = ctx->i16[3];

    f[47] = ctx->i8[0];
    f[48] = ctx->i8[1];
    f[49] = ctx->i8[2];
    f[50] = ctx->i8[3];
    f[51] = ctx->i8[4];
    f[52] = ctx->i8[5];
    f[53] = ctx->i8[6];
    f[54] = ctx->i8[7];
    f[55] = ctx->i8[8];

    f[56] = ctx->i4[0];
    f[57] = ctx->i4[1];
    f[58] = ctx->i4[2];
    f[59] = ctx->i4[3];
    f[60] = ctx->i4[4];
    f[61] = ctx->i4[5];
    f[62] = ctx->i4[6];
    f[63] = ctx->i4[7];
    f[64] = ctx->i4[8];

    f[65] = ctx->i8c[0];
    f[66] = ctx->i8c[1];
    f[67] = ctx->i8c[2];
    f[68] = ctx->i8c[3];

    f[69] = ctx->weighted_p_y;
    f[70] = ctx->weighted_p_uv;

    f[71] = ctx->ref_p_l0[0];
    f[72] = ctx->ref_p_l0[1];
    f[73] = ctx->ref_p_l0[2];
    f[74] = ctx->ref_p_l0[3];

    f[75] = ctx->ref_b_l0[0];
    f[76] = ctx->ref_b_l0[1];
    f[77] = ctx->ref_b_l0[2];

    f[78] = ctx->ref_b_l1[0];
    f[79] = ctx->ref_b_l1[1];
}

double ffmetric_predict(const FFMetricContext *ctx)
{
    double f[FFMETRIC_XGB_N_FEATURES];

    if (!ctx)
        return 0.0;

    memset(f, 0, sizeof(f));

    ffmetric_fill_features(ctx, f);

    return ffmetric_xgb_predict_raw(f);
}
