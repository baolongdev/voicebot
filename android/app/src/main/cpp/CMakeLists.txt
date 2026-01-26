cmake_minimum_required(VERSION 3.18.1)

project(opus_codec CXX)

add_library(opus_codec SHARED opus_recorder.cpp opus_decoder.cpp)

find_package(opus REQUIRED CONFIG)
target_link_libraries(opus_codec opus::libopus.so)
target_link_libraries(opus_codec log)
