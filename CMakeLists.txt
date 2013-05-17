cmake_minimum_required(VERSION 2.8.8)
project (omap-flash-utils)

SET (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror")

# Define Executable Output Directory
set (EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR})

# Versioning
set (omap-flash-utils_VERSION_MAJOR 0)
set (omap-flash-utils_VERSION_MINOR 0)
set (omap-flash-utils_VERSION_PATCH 0)

# Includes
include_directories("${PROJECT_SOURCE_DIR}/include")

add_subdirectory(lib)
add_subdirectory(src)
