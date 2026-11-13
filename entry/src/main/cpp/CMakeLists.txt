cmake_minimum_required(VERSION 3.16)
project(voxprobe C)

add_library(voxprobe SHARED media_probe.c audio_decode.c)
target_compile_features(voxprobe PRIVATE c_std_17)
target_link_libraries(voxprobe PRIVATE
    libace_napi.z.so libhilog_ndk.z.so libnative_media_avsource.so
    libnative_media_avdemuxer.so libnative_media_acodec.so libnative_media_avmuxer.so
    libnative_media_core.so libnative_media_codecbase.so)
