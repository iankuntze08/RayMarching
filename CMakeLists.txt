cmake_minimum_required(VERSION 3.0...3.25)


project(
    RaytracingGL
    VERSION 0.0.2
    LANGUAGES C CXX
)


set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(RaytracingGL
    src/main.cpp
    external/glad/src/glad.c
)

target_include_directories(RaytracingGL PRIVATE
    external/glad/include
)

target_include_directories(RaytracingGL PRIVATE
    external/glfw/include
)

target_include_directories(RaytracingGL PRIVATE
    external/glm
)

target_link_libraries(RaytracingGL PRIVATE
    "${CMAKE_SOURCE_DIR}/external/glfw_lib/glfw3.lib"
)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
