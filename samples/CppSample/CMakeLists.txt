cmake_minimum_required(VERSION 3.20)
project(PdfToImageCppSample CXX)

add_executable(PdfToImageCppSample main.cpp)

if (MSVC)
    target_compile_options(PdfToImageCppSample PRIVATE /W4 /utf-8)
endif()
