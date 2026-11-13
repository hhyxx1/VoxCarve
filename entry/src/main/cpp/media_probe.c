#define LOG_TAG "VoxCarveNative"
#include <napi/native_api.h>
#include "audio_decode.h"
#include <hilog/log.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <multimedia/player_framework/native_avbuffer.h>
#include <multimedia/player_framework/native_avcodec_audiocodec.h>
#include <multimedia/player_framework/native_avdemuxer.h>
#include <multimedia/player_framework/native_avmuxer.h>
#include <multimedia/player_framework/native_avsource.h>

static int probe_wav(int fd, int64_t offset, int64_t length)
{
    int result = 1;
    OH_AVSource *source = OH_AVSource_CreateWithFD(fd, offset, length);
    OH_AVDemuxer *demuxer = source ? OH_AVDemuxer_CreateWithSource(source) : NULL;
    OH_AVFormat *track = source ? OH_AVSource_GetTrackFormat(source, 0) : NULL;
    OH_AVBuffer *buffer = OH_AVBuffer_Create(65536);
    const char *mime = NULL;
    int32_t rate = 0;
    int32_t channels = 0;
    if (track && buffer && demuxer &&
        OH_AVFormat_GetStringValue(track, OH_MD_KEY_CODEC_MIME, &mime) &&
        OH_AVFormat_GetIntValue(track, OH_MD_KEY_AUD_SAMPLE_RATE, &rate) &&
        OH_AVFormat_GetIntValue(track, OH_MD_KEY_AUD_CHANNEL_COUNT, &channels)) {
        OH_AVErrCode selected = OH_AVDemuxer_SelectTrackByID(demuxer, 0);
        OH_AVErrCode read = selected == AV_ERR_OK ?
            OH_AVDemuxer_ReadSampleBuffer(demuxer, 0, buffer) : selected;
        OH_AVCodecBufferAttr attr = {0};
        if (read == AV_ERR_OK && OH_AVBuffer_GetBufferAttr(buffer, &attr) == AV_ERR_OK && attr.size > 0) {
            OH_LOG_INFO(LOG_APP, "WAV: %{public}s %{public}d Hz %{public}d ch, first buffer %{public}d bytes, PTS %{public}" PRId64 " us\n",
                mime, rate, channels, attr.size, attr.pts);
            result = 0;
        } else {
            OH_LOG_INFO(LOG_APP, "WAV: sample read status %{public}d\n", read);
        }
    } else {
        OH_LOG_INFO(LOG_APP, "WAV: source/track/demuxer/buffer unavailable\n");
    }

    if (buffer) {
        OH_AVBuffer_Destroy(buffer);
    }
    if (track) {
        OH_AVFormat_Destroy(track);
    }
    if (demuxer) {
        OH_AVDemuxer_Destroy(demuxer);
    }
    if (source) {
        OH_AVSource_Destroy(source);
    }
    return result;
}

static int probe_codec(const char *mime, bool encoder)
{
    OH_AVCodec *codec = OH_AudioCodec_CreateByMime(mime, encoder);
    OH_LOG_INFO(LOG_APP, "%{public}s %{public}s: %{public}s\n", encoder ? "Encoder" : "Decoder", mime, codec ? "created" : "unavailable");
    if (!codec) {
        return 1;
    }
    return OH_AudioCodec_Destroy(codec) == AV_ERR_OK ? 0 : 1;
}

static int probe_muxer(const char *cacheDir)
{
    char output[1024];
    int size = snprintf(output, sizeof(output), "%s/voxcarve-mux-XXXXXX", cacheDir);
    if (size < 0 || (size_t)size >= sizeof(output)) {
        return 1;
    }
    int fd = mkstemp(output);
    if (fd < 0) {
        perror("mkstemp");
        return 1;
    }
    OH_AVMuxer *muxer = OH_AVMuxer_Create(fd, AV_OUTPUT_FORMAT_MPEG_4);
    OH_LOG_INFO(LOG_APP, "MP4 muxer: %{public}s\n", muxer ? "created" : "unavailable");
    int result = muxer && OH_AVMuxer_Destroy(muxer) == AV_ERR_OK ? 0 : 1;
    close(fd);
    unlink(output);
    return result;
}


static napi_value RunProbe(napi_env env, napi_callback_info info)
{
    size_t count = 4;
    napi_value args[4];
    int32_t fd = -1;
    int64_t offset = 0;
    int64_t length = 0;
    char cacheDir[768];
    size_t pathSize = 0;
    if (napi_get_cb_info(env, info, &count, args, NULL, NULL) != napi_ok || count != 4 ||
        napi_get_value_int32(env, args[0], &fd) != napi_ok ||
        napi_get_value_int64(env, args[1], &offset) != napi_ok ||
        napi_get_value_int64(env, args[2], &length) != napi_ok ||
        napi_get_value_string_utf8(env, args[3], cacheDir, sizeof(cacheDir), &pathSize) != napi_ok ||
        fd < 0 || offset < 0 || length <= 0 || pathSize == 0 || pathSize >= sizeof(cacheDir) - 1) {
        napi_throw_type_error(env, NULL, "Invalid media probe input");
        return NULL;
    }

    int failed = 0;
    failed |= probe_wav(fd, offset, length) << 0;
    failed |= probe_codec(OH_AVCODEC_MIMETYPE_AUDIO_AAC, false) << 1;
    failed |= probe_codec(OH_AVCODEC_MIMETYPE_AUDIO_AAC, true) << 2;
    failed |= probe_codec(OH_AVCODEC_MIMETYPE_AUDIO_MPEG, true) << 3;
    failed |= probe_muxer(cacheDir) << 4;
    napi_value result;
    if (napi_create_int32(env, failed, &result) != napi_ok) {
        return NULL;
    }
    return result;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor methods[] = {
        { .utf8name = "runProbe", .method = RunProbe },
        { .utf8name = "decodeAudio", .method = VoxDecodeAudio },
    };
    if (napi_define_properties(env, exports, sizeof(methods) / sizeof(methods[0]), methods) != napi_ok) {
        return NULL;
    }
    return exports;
}

static napi_module module = {
    .nm_version = 1,
    .nm_register_func = Init,
    .nm_modname = "voxprobe",
};

__attribute__((constructor)) static void RegisterProbe(void)
{
    napi_module_register(&module);
}
