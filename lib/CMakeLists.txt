include_directories("${CMAKE_CURRENT_LIST_DIR}/lcfg")

if (WIN32)
	set (LIB_SOURCES ${PROJECT_SOURCE_DIR}/lib/serial_win32.c ${PROJECT_SOURCE_DIR}/lib/file_win32.c) 
else (WIN32)
	set (LIB_SOURCES ${PROJECT_SOURCE_DIR}/lib/serial_posix.c ${PROJECT_SOURCE_DIR}/lib/file_posix.c) 
endif (WIN32)

list(APPEND LIB_SOURCES ${PROJECT_SOURCE_DIR}/lib/f_status.c ${PROJECT_SOURCE_DIR}/lib/lcfg/lcfg_static.c)

add_library(LIB_OBJECTS OBJECT ${LIB_SOURCES})
