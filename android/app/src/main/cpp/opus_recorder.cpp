#include <string>
#include <android/log.h>
#include <opus/opus.h>
#include <stdint.h>

#define LOG_TAG "OpusJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Ported from Android NDK: opus_recorder.cpp
extern "C" {

void* opus_encoder_init(int sample_rate, int channels, int application) {
    int error;
    OpusEncoder* encoder = opus_encoder_create(sample_rate, channels, application, &error);

    if (error != OPUS_OK || encoder == nullptr) {
        LOGE("Failed to create encoder: %s", opus_strerror(error));
        return nullptr;
    }

    opus_encoder_ctl(encoder, OPUS_SET_BITRATE(64000));
    opus_encoder_ctl(encoder, OPUS_SET_COMPLEXITY(10));

    LOGI("Opus encoder initialized: sample_rate=%d, channels=%d", sample_rate, channels);
    return reinterpret_cast<void*>(encoder);
}

int opus_encoder_encode(void* encoder_handle,
                        const uint8_t* input_buffer,
                        int input_size,
                        uint8_t* output_buffer,
                        int max_output_size) {
    OpusEncoder* encoder = reinterpret_cast<OpusEncoder*>(encoder_handle);
    if (encoder == nullptr) {
        LOGE("Encoder handle is null");
        return -1;
    }

    const opus_int16* pcm = reinterpret_cast<const opus_int16*>(input_buffer);
    int frame_size = input_size / 2;

    int result = opus_encode(encoder, pcm, frame_size, output_buffer, max_output_size);
    if (result < 0) {
        LOGE("Encoding failed: %s", opus_strerror(result));
        return -1;
    }

    return result;
}

void opus_encoder_destroy(void* encoder_handle) {
    OpusEncoder* encoder = reinterpret_cast<OpusEncoder*>(encoder_handle);
    if (encoder != nullptr) {
        opus_encoder_destroy(encoder);
        LOGI("Opus encoder released");
    }
}

}
