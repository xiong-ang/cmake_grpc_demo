project(client VERSION 0.1.0)

find_package(Protobuf REQUIRED)
cmake_policy(SET CMP0071 NEW)
set(PROTOBUF_GENERATE_CPP_APPEND_PATH TRUE)
SET(PROTOBUF_IMPORT_DIRS
    ../api
)
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS
    ../api/helloworld.proto
)
find_package(gRPC CONFIG REQUIRED)
set(GRPC_GENERATE_CPP_APPEND_PATH TRUE)
SET(GRPC_IMPORT_DIRS
    ../api
)
include(../gRPCGenerate.cmake)
grpc_generate_cpp(GRPC_PROTO_SRCS GRPC_PROTO_HDRS
    ../api/helloworld.proto
)
source_group(grpcProto FILES ${PROTO_SRCS} ${PROTO_HDRS} ${GRPC_PROTO_SRCS} ${GRPC_PROTO_HDRS})

add_executable(${PROJECT_NAME} 
    main.cpp
    ${PROTO_SRCS}
    ${PROTO_HDRS}
    ${GRPC_PROTO_SRCS}
    ${GRPC_PROTO_HDRS}
)

# grpc
find_package(gRPC CONFIG REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE gRPC::grpc++ gRPC::grpc gRPC::gpr)

target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_LIST_DIR})
target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_BINARY_DIR})

target_compile_definitions(${PROJECT_NAME} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN QT_MESSAGELOGCONTEXT _SILENCE_CXX17_ITERATOR_BASE_CLASS_DEPRECATION_WARNING)

target_compile_options(${PROJECT_NAME} PRIVATE "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<COMPILE_LANGUAGE:CXX>>:/utf-8>")
target_compile_options(${PROJECT_NAME} PRIVATE "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<COMPILE_LANGUAGE:CXX>>:/MP>")

target_compile_options(${PROJECT_NAME} PRIVATE $<$<AND:$<CXX_COMPILER_ID:MSVC>,$<COMPILE_LANGUAGE:CXX>>:/wd4251>)