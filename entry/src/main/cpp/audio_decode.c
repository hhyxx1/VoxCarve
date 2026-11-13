#include "audio_decode.h"

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <multimedia/player_framework/native_avcodec_audiocodec.h>
#include <multimedia/player_framework/native_avdemuxer.h>
#include <multimedia/player_framework/native_avsource.h>

enum {
    DECODE_OK, DECODE_SOURCE, DECODE_UNSUPPORTED, DECODE_CONFIG, DECODE_READ,
    DECODE_PCM, DECODE_WRITE, DECODE_TIMEOUT
};

typedef struct {
    int input;
    int output;
    int64_t length;
    napi_async_work work;
    napi_deferred promise;
    int result;
} DecodeJob;

typedef struct {
    int fd;
    int32_t rate;
    int32_t channels;
    uint32_t bytes;
    int64_t lastPts;
} WaveOutput;

static bool WriteAll(int fd, const uint8_t *data, size_t length)
{
    while (length > 0) {
        ssize_t count = write(fd, data, length);
        if (count < 0 && errno == EINTR) {
            continue;
        }
        if (count <= 0) {
            return false;
        }
        data += count;
        length -= (size_t)count;
    }
    return true;
}

static void PutLittle(uint8_t *out, uint32_t value, size_t bytes)
{
    for (size_t index = 0; index < bytes; index++) {
        out[index] = (uint8_t)(value >> (8 * index));
    }
}

static bool FinishWave(const WaveOutput *wave)
{
    uint8_t header[44] = {0};
    memcpy(header, "RIFF", 4);
    PutLittle(header + 4, wave->bytes + 36, 4);
    memcpy(header + 8, "WAVEfmt ", 8);
    PutLittle(header + 16, 16, 4);
    PutLittle(header + 20, 1, 2);
    PutLittle(header + 22, (uint32_t)wave->channels, 2);
    PutLittle(header + 24, (uint32_t)wave->rate, 4);
    PutLittle(header + 28, (uint32_t)(wave->rate * wave->channels * 2), 4);
    PutLittle(header + 32, (uint32_t)(wave->channels * 2), 2);
    PutLittle(header + 34, 16, 2);
    memcpy(header + 36, "data", 4);
    PutLittle(header + 40, wave->bytes, 4);
    return lseek(wave->fd, 0, SEEK_SET) == 0 && WriteAll(wave->fd, header, sizeof(header)) && fsync(wave->fd) == 0;
}

static bool ReadPcmFormat(OH_AVCodec *codec, WaveOutput *wave)
{
    OH_AVFormat *format = OH_AudioCodec_GetOutputDescription(codec);
    int32_t rate = 0;
    int32_t channels = 0;
    int32_t sample = -1;
    if (!format || !OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_SAMPLE_RATE, &rate) ||
        !OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_CHANNEL_COUNT, &channels) ||
        !OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUDIO_SAMPLE_FORMAT, &sample) ||
        sample != SAMPLE_S16LE || rate < 8000 || rate > 192000 || (channels != 1 && channels != 2)) {
        return false;
    }
    if (wave->bytes != 0 && (rate != wave->rate || channels != wave->channels)) {
        return false;
    }
    wave->rate = rate;
    wave->channels = channels;
    return true;
}

static int WritePcm(OH_AVCodec *codec, uint32_t index, WaveOutput *wave, bool *eos)
{
    OH_AVBuffer *buffer = OH_AudioCodec_GetOutputBuffer(codec, index);
    OH_AVCodecBufferAttr attr = {0};
    if (!buffer || OH_AVBuffer_GetBufferAttr(buffer, &attr) != AV_ERR_OK) {
        return DECODE_PCM;
    }
    *eos = (attr.flags & AVCODEC_BUFFER_FLAGS_EOS) != 0;
    // The decoder can echo demuxer flags on PCM and return stale attributes on EOS.
    if (*eos || attr.size == 0) {
        return DECODE_OK;
    }
    uint8_t *data = OH_AVBuffer_GetAddr(buffer);
    int32_t capacity = OH_AVBuffer_GetCapacity(buffer);
    if ((wave->channels == 0 && !ReadPcmFormat(codec, wave)) || !data || attr.offset < 0 ||
        attr.size < 0 || attr.offset > capacity || attr.size > capacity - attr.offset ||
        attr.size % (wave->channels * 2) != 0 || (uint32_t)attr.size > UINT32_MAX - 36 - wave->bytes ||
        (wave->bytes != 0 && attr.pts < wave->lastPts)) {
        return DECODE_PCM;
    }
    if (!WriteAll(wave->fd, data + attr.offset, (size_t)attr.size)) {
        return DECODE_WRITE;
    }
    wave->bytes += (uint32_t)attr.size;
    wave->lastPts = attr.pts;
    return DECODE_OK;
}

static int DecodePackets(OH_AVCodec *codec, OH_AVDemuxer *demuxer, uint32_t track, WaveOutput *wave)
{
    bool inputEos = false;
    bool outputEos = false;
    unsigned idle = 0;
    while (!outputEos) {
        bool advanced = false;
        uint32_t index = 0;
        if (!inputEos) {
            OH_AVErrCode status = OH_AudioCodec_QueryInputBuffer(codec, &index, 1000);
            if (status == AV_ERR_OK) {
                OH_AVBuffer *buffer = OH_AudioCodec_GetInputBuffer(codec, index);
                OH_AVCodecBufferAttr attr = {0};
                if (!buffer || OH_AVDemuxer_ReadSampleBuffer(demuxer, track, buffer) != AV_ERR_OK ||
                    OH_AVBuffer_GetBufferAttr(buffer, &attr) != AV_ERR_OK ||
                    OH_AudioCodec_PushInputBuffer(codec, index) != AV_ERR_OK) {
                    return DECODE_READ;
                }
                inputEos = (attr.flags & AVCODEC_BUFFER_FLAGS_EOS) != 0;
                advanced = true;
            } else if (status != AV_ERR_TRY_AGAIN_LATER) {
                return DECODE_READ;
            }
        }
        OH_AVErrCode status = OH_AudioCodec_QueryOutputBuffer(codec, &index, advanced ? 1000 : 10000);
        if (status == AV_ERR_OK) {
            int result = WritePcm(codec, index, wave, &outputEos);
            OH_AVErrCode freed = OH_AudioCodec_FreeOutputBuffer(codec, index);
            if (result != DECODE_OK || freed != AV_ERR_OK) {
                return result != DECODE_OK ? result : DECODE_PCM;
            }
            advanced = true;
        } else if (status == AV_ERR_STREAM_CHANGED) {
            if (!ReadPcmFormat(codec, wave)) {
                return DECODE_PCM;
            }
            advanced = true;
        } else if (status != AV_ERR_TRY_AGAIN_LATER) {
            return DECODE_PCM;
        }
        idle = advanced ? 0 : idle + 1;
        if (idle >= 500) {
            return DECODE_TIMEOUT;
        }
    }
    return inputEos && wave->bytes > 0 ? DECODE_OK : DECODE_PCM;
}

static OH_AVFormat *FindAudio(OH_AVSource *source, uint32_t *track)
{
    OH_AVFormat *metadata = OH_AVSource_GetSourceFormat(source);
    int32_t count = 0;
    if (metadata) {
        OH_AVFormat_GetIntValue(metadata, OH_MD_KEY_TRACK_COUNT, &count);
        OH_AVFormat_Destroy(metadata);
    }
    OH_AVFormat *audio = NULL;
    for (int32_t index = 0; index < count; index++) {
        OH_AVFormat *format = OH_AVSource_GetTrackFormat(source, (uint32_t)index);
        int32_t type = -1;
        if (!format || !OH_AVFormat_GetIntValue(format, OH_MD_KEY_TRACK_TYPE, &type) ||
            type == MEDIA_TYPE_VID || (type == MEDIA_TYPE_AUD && audio)) {
            if (format) {
                OH_AVFormat_Destroy(format);
            }
            if (audio) {
                OH_AVFormat_Destroy(audio);
            }
            return NULL;
        }
        if (type == MEDIA_TYPE_AUD) {
            audio = format;
            *track = (uint32_t)index;
        } else {
            OH_AVFormat_Destroy(format);
        }
    }
    return audio;
}

static int Decode(DecodeJob *job)
{
    int result = DECODE_SOURCE;
    uint32_t track = 0;
    OH_AVSource *source = OH_AVSource_CreateWithFD(job->input, 0, job->length);
    OH_AVFormat *format = source ? FindAudio(source, &track) : NULL;
    OH_AVDemuxer *demuxer = NULL;
    OH_AVCodec *codec = NULL;
    const char *mime = NULL;
    if (!source) {
        goto cleanup;
    }
    result = DECODE_UNSUPPORTED;
    if (!format || !OH_AVFormat_GetStringValue(format, OH_MD_KEY_CODEC_MIME, &mime) ||
        (strcmp(mime, OH_AVCODEC_MIMETYPE_AUDIO_MPEG) != 0 && strcmp(mime, OH_AVCODEC_MIMETYPE_AUDIO_AAC) != 0)) {
        goto cleanup;
    }
    codec = OH_AudioCodec_CreateByMime(mime, false);
    if (!codec) {
        goto cleanup;
    }
    result = DECODE_CONFIG;
    demuxer = OH_AVDemuxer_CreateWithSource(source);
    if (!demuxer || OH_AVDemuxer_SelectTrackByID(demuxer, track) != AV_ERR_OK ||
        !OH_AVFormat_SetIntValue(format, OH_MD_KEY_ENABLE_SYNC_MODE, 1) ||
        !OH_AVFormat_SetIntValue(format, OH_MD_KEY_AUDIO_SAMPLE_FORMAT, SAMPLE_S16LE) ||
        OH_AudioCodec_Configure(codec, format) != AV_ERR_OK ||
        OH_AudioCodec_Prepare(codec) != AV_ERR_OK || OH_AudioCodec_Start(codec) != AV_ERR_OK) {
        goto cleanup;
    }
    result = DECODE_WRITE;
    const uint8_t header[44] = {0};
    if (lseek(job->output, 0, SEEK_SET) != 0 || !WriteAll(job->output, header, sizeof(header))) {
        goto cleanup;
    }
    WaveOutput wave = { .fd = job->output };
    result = DecodePackets(codec, demuxer, track, &wave);
    if (result == DECODE_OK && !FinishWave(&wave)) {
        result = DECODE_WRITE;
    }
cleanup:
    if (codec) {
        OH_AudioCodec_Destroy(codec);
    }
    if (demuxer) {
        OH_AVDemuxer_Destroy(demuxer);
    }
    if (format) {
        OH_AVFormat_Destroy(format);
    }
    if (source) {
        OH_AVSource_Destroy(source);
    }
    return result;
}

static void Execute(napi_env env, void *data)
{
    (void)env;
    DecodeJob *job = data;
    job->result = Decode(job);
}

static void Complete(napi_env env, napi_status status, void *data)
{
    DecodeJob *job = data;
    napi_value result;
    if (napi_create_int32(env, status == napi_ok ? job->result : DECODE_READ, &result) == napi_ok) {
        napi_resolve_deferred(env, job->promise, result);
    }
    napi_delete_async_work(env, job->work);
    free(job);
}

napi_value VoxDecodeAudio(napi_env env, napi_callback_info info)
{
    size_t count = 3;
    napi_value args[3];
    int32_t input = -1;
    int32_t output = -1;
    int64_t length = 0;
    if (napi_get_cb_info(env, info, &count, args, NULL, NULL) != napi_ok || count != 3 ||
        napi_get_value_int32(env, args[0], &input) != napi_ok ||
        napi_get_value_int64(env, args[1], &length) != napi_ok ||
        napi_get_value_int32(env, args[2], &output) != napi_ok || input < 0 || output < 0 || length <= 0) {
        napi_throw_type_error(env, NULL, "Invalid audio decode descriptors");
        return NULL;
    }
    DecodeJob *job = calloc(1, sizeof(*job));
    if (!job) {
        napi_throw_error(env, NULL, "AUDIO_DECODE_MEMORY");
        return NULL;
    }
    job->input = input;
    job->output = output;
    job->length = length;
    napi_value name;
    napi_value promise;
    if (napi_create_string_utf8(env, "VoxCarveDecodeAudio", NAPI_AUTO_LENGTH, &name) != napi_ok ||
        napi_create_promise(env, &job->promise, &promise) != napi_ok ||
        napi_create_async_work(env, NULL, name, Execute, Complete, job, &job->work) != napi_ok ||
        napi_queue_async_work(env, job->work) != napi_ok) {
        if (job->work) {
            napi_delete_async_work(env, job->work);
        }
        free(job);
        napi_throw_error(env, NULL, "AUDIO_DECODE_QUEUE");
        return NULL;
    }
    return promise;
}
