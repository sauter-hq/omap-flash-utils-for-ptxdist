# lcfg dependency
include_directories(${PROJECT_SOURCE_DIR}/lib/lcfg)

add_executable(pserial pserial.c $<TARGET_OBJECTS:LIB_OBJECTS>)
add_executable(ukermit ukermit.c $<TARGET_OBJECTS:LIB_OBJECTS>)
add_executable(ucmd ucmd.c $<TARGET_OBJECTS:LIB_OBJECTS>)
add_executable(gpsign gpsign.c $<TARGET_OBJECTS:LIB_OBJECTS>)
add_executable(tagger tagger.c $<TARGET_OBJECTS:LIB_OBJECTS>)
