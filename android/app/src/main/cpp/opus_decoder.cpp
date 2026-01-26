#include <string>
#include <android/log.h>
#include <opus/opus.h>
#include <stdint.h>

#define LOG_TAG "OpusJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Ported from Android NDK: opus_decoder.cpp
extern "C" {

void* opus_decoder_init(int sample_rate, int channels) {
    int error;
    OpusDecoder* decoder = opus_decoder_create(sample_rate, channels, &error);

    if (error != OPUS_OK || decoder == nullptr) {
        LOGE("Failed to create decoder: %s", opus_strerror(error));
        return nullptr;
    }

    LOGI("Opus decoder initialized: sample_rate=%d, channels=%d", sample_rate, channels);
    return reinterpret_cast<void*>(decoder);
}

int opus_decoder_decode(void* decoder_handle,
                        const uint8_t* input_buffer,
                        int input_size,
                        uint8_t* output_buffer,
                        int max_output_size) {
    OpusDecoder* decoder = reinterpret_cast<OpusDecoder*>(decoder_handle);
    if (decoder == nullptr) {
        LOGE("Decoder handle is null");
        return -1;
    }

    int frame_size = max_output_size / 2;
    int result = opus_decode(decoder,
                             input_buffer,
                             input_size,
                             reinterpret_cast<opus_int16*>(output_buffer),
                             frame_size,
                             0);

    if (result < 0) {
        LOGE("Decoding failed: %s", opus_strerror(result));
        return -1;
    }

    return result * 2;
}

void opus_decoder_destroy(void* decoder_handle) {
    OpusDecoder* decoder = reinterpret_cast<OpusDecoder*>(decoder_handle);
    if (decoder != nullptr) {
        opus_decoder_destroy(decoder);
        LOGI("Opus decoder released");
    }
}

}
