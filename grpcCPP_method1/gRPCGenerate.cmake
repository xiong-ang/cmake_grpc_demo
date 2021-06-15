function(grpc_generate)
  set(_options APPEND_PATH DESCRIPTORS)
  set(_singleargs LANGUAGE OUT_VAR EXPORT_MACRO PROTOC_OUT_DIR GENERATE_PLUGIN)
  if(COMMAND target_sources)
    list(APPEND _singleargs TARGET)
  endif()
  set(_multiargs PROTOS IMPORT_DIRS GENERATE_EXTENSIONS)

  cmake_parse_arguments(grpc_generate "${_options}" "${_singleargs}" "${_multiargs}" "${ARGN}")

  if(NOT grpc_generate_PROTOS AND NOT grpc_generate_TARGET)
    message(SEND_ERROR "Error: grpc_generate called without any targets or source files")
    return()
  endif()

  if(NOT grpc_generate_OUT_VAR AND NOT grpc_generate_TARGET)
    message(SEND_ERROR "Error: grpc_generate called without a target or output variable")
    return()
  endif()

  if(NOT grpc_generate_LANGUAGE)
    set(grpc_generate_LANGUAGE cpp)
  endif()
  string(TOLOWER ${grpc_generate_LANGUAGE} grpc_generate_LANGUAGE)

  if(NOT grpc_generate_PROTOC_OUT_DIR)
    set(grpc_generate_PROTOC_OUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
  endif()

  if(grpc_generate_EXPORT_MACRO AND grpc_generate_LANGUAGE STREQUAL cpp)
    set(_dll_export_decl "dllexport_decl=${grpc_generate_EXPORT_MACRO}:")
  endif()

  if(NOT grpc_generate_GENERATE_EXTENSIONS)
    if(grpc_generate_LANGUAGE STREQUAL cpp)
      set(grpc_generate_GENERATE_EXTENSIONS .grpc.pb.h .grpc.pb.cc)
    else()
      message(SEND_ERROR "Error: grpc_generate given unknown Language ${LANGUAGE}, please provide a value for GENERATE_EXTENSIONS")
      return()
    endif()
  endif()

  if(NOT grpc_generate_GENERATE_PLUGIN)
      set(grpc_generate_GENERATE_PLUGIN "gRPC::grpc_${grpc_generate_LANGUAGE}_plugin")
  endif()

  if(grpc_generate_TARGET)
    get_target_property(_source_list ${grpc_generate_TARGET} SOURCES)
    foreach(_file ${_source_list})
      if(_file MATCHES "proto$")
        list(APPEND grpc_generate_PROTOS ${_file})
      endif()
    endforeach()
  endif()

  if(NOT grpc_generate_PROTOS)
    message(SEND_ERROR "Error: grpc_generate could not find any .proto files")
    return()
  endif()

  if(grpc_generate_APPEND_PATH)
    # Create an include path for each file specified
    foreach(_file ${grpc_generate_PROTOS})
      get_filename_component(_abs_file ${_file} ABSOLUTE)
      get_filename_component(_abs_path ${_abs_file} PATH)
      list(FIND _grpc_include_path ${_abs_path} _contains_already)
      if(${_contains_already} EQUAL -1)
          list(APPEND _grpc_include_path -I ${_abs_path})
      endif()
    endforeach()
  else()
    set(_grpc_include_path -I ${CMAKE_CURRENT_SOURCE_DIR})
  endif()

  foreach(DIR ${grpc_generate_IMPORT_DIRS})
    get_filename_component(ABS_PATH ${DIR} ABSOLUTE)
    list(FIND _grpc_include_path ${ABS_PATH} _contains_already)
    if(${_contains_already} EQUAL -1)
        list(APPEND _grpc_include_path -I ${ABS_PATH})
    endif()
  endforeach()

  set(_generated_srcs_all)
  foreach(_proto ${grpc_generate_PROTOS})
    get_filename_component(_abs_file ${_proto} ABSOLUTE)
    get_filename_component(_abs_dir ${_abs_file} DIRECTORY)
    get_filename_component(_basename ${_proto} NAME_WE)
    file(RELATIVE_PATH _rel_dir ${CMAKE_CURRENT_SOURCE_DIR} ${_abs_dir})

    set(_possible_rel_dir)
    if (NOT grpc_generate_APPEND_PATH)
        set(_possible_rel_dir ${_rel_dir}/)
    endif()

    set(_generated_srcs)
    foreach(_ext ${grpc_generate_GENERATE_EXTENSIONS})
      list(APPEND _generated_srcs "${grpc_generate_PROTOC_OUT_DIR}/${_possible_rel_dir}${_basename}${_ext}")
    endforeach()

    if(grpc_generate_DESCRIPTORS AND grpc_generate_LANGUAGE STREQUAL cpp)
      set(_descriptor_file "${CMAKE_CURRENT_BINARY_DIR}/${_basename}.desc")
      set(_dll_desc_out "--descriptor_set_out=${_descriptor_file}")
      list(APPEND _generated_srcs ${_descriptor_file})
    endif()
    list(APPEND _generated_srcs_all ${_generated_srcs})

    get_target_property(_grpc_plugin_location ${grpc_generate_GENERATE_PLUGIN} LOCATION)

    add_custom_command(
      OUTPUT ${_generated_srcs}
      COMMAND  protobuf::protoc
      ARGS --grpc_out ${_dll_export_decl} ${grpc_generate_PROTOC_OUT_DIR} ${_dll_desc_out} ${_grpc_include_path} ${_abs_file} --plugin=protoc-gen-grpc=${_grpc_plugin_location}
      DEPENDS ${_abs_file} protobuf::protoc ${grpc_generate_GENERATE_PLUGIN}
      COMMENT "Running ${grpc_generate_LANGUAGE} gRPC compiler on ${_proto}"
      VERBATIM )
  endforeach()

  set_source_files_properties(${_generated_srcs_all} PROPERTIES GENERATED TRUE)
  if(grpc_generate_OUT_VAR)
    set(${grpc_generate_OUT_VAR} ${_generated_srcs_all} PARENT_SCOPE)
  endif()
  if(grpc_generate_TARGET)
    target_sources(${grpc_generate_TARGET} PRIVATE ${_generated_srcs_all})
  endif()
endfunction()

function(GRPC_GENERATE_CPP SRCS HDRS)
  cmake_parse_arguments(grpc_generate_cpp "" "EXPORT_MACRO;DESCRIPTORS" "" ${ARGN})

  set(_proto_files "${grpc_generate_cpp_UNPARSED_ARGUMENTS}")
  if(NOT _proto_files)
    message(SEND_ERROR "Error: GRPC_GENERATE_CPP() called without any proto files")
    return()
  endif()

  if(GRPC_GENERATE_CPP_APPEND_PATH)
    set(_append_arg APPEND_PATH)
  endif()

  if(grpc_generate_cpp_DESCRIPTORS)
    set(_descriptors DESCRIPTORS)
  endif()

  if(DEFINED GRPC_IMPORT_DIRS AND NOT DEFINED gRPC_IMPORT_DIRS)
    set(gRPC_IMPORT_DIRS "${GRPC_IMPORT_DIRS}")
  endif()

  if(DEFINED gRPC_IMPORT_DIRS)
    set(_import_arg IMPORT_DIRS ${gRPC_IMPORT_DIRS})
  endif()

  set(_outvar)
  grpc_generate(${_append_arg} ${_descriptors} LANGUAGE cpp EXPORT_MACRO ${grpc_generate_cpp_EXPORT_MACRO} OUT_VAR _outvar ${_import_arg} PROTOS ${_proto_files})

  set(${SRCS})
  set(${HDRS})
  if(grpc_generate_cpp_DESCRIPTORS)
    set(${grpc_generate_cpp_DESCRIPTORS})
  endif()

  foreach(_file ${_outvar})
    if(_file MATCHES "cc$")
      list(APPEND ${SRCS} ${_file})
    elseif(_file MATCHES "desc$")
      list(APPEND ${grpc_generate_cpp_DESCRIPTORS} ${_file})
    else()
      list(APPEND ${HDRS} ${_file})
    endif()
  endforeach()
  set(${SRCS} ${${SRCS}} PARENT_SCOPE)
  set(${HDRS} ${${HDRS}} PARENT_SCOPE)
  if(grpc_generate_cpp_DESCRIPTORS)
    set(${grpc_generate_cpp_DESCRIPTORS} "${${grpc_generate_cpp_DESCRIPTORS}}" PARENT_SCOPE)
  endif()
endfunction()