set(ARM_C_COMPILER "arm-none-eabi-gcc")
set(ARM_ASM_COMPILER "arm-none-eabi-gcc")
set(ARM_CXX_COMPILER "arm-none-eabi-g++")
set(ARM_OBJCOPY "arm-none-eabi-objcopy")

find_program(ARM_C_COMPILER_PATH ${ARM_C_COMPILER})

if (NOT ARM_C_COMPILER_PATH)
    message(STATUS "Build luci-micro: FALSE(ARM compiler is NOT FOUND)")
    return()
endif ()

nnas_find_package(FlatBuffers EXACT 2.0 QUIET)

if (NOT FlatBuffers_FOUND)
    message(STATUS "Build luci-micro: FALSE(FlatBuffers 2.0 NOT FOUND)")
    return()
endif (NOT FlatBuffers_FOUND)

message(STATUS "Build luci-micro: TRUE")

set(SCHEMA_FILE "${NNAS_PROJECT_SOURCE_DIR}/res/CircleSchema/0.4/circle_schema.fbs")

# NOTE Copy circle_schema.fbs as schema.fbs to generate "schema_generated.fbs" instead of "circle_schema_generated.fbs"
add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/schema.fbs"
        COMMAND ${CMAKE_COMMAND} -E copy "${SCHEMA_FILE}" schema.fbs
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        DEPENDS "${SCHEMA_FILE}"
        )

FlatBuffers_Target(luci_micro_circle_schema
        OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/gen/circle-generated/circle"
        INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/gen"
        SCHEMA_DIR "${CMAKE_CURRENT_BINARY_DIR}"
        SCHEMA_FILES "schema.fbs"
        )

set(LUCI_INTERPRETER_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/include")
add_subdirectory(luci-interpreter/src/core/reader)

# Choosing Kernel: reference mcu, optimized cmsisnn, optimized linux
if (NOT KERNELS)
    message(STATUS "KERNEL variable is not defined, default reference mcu kernels will be used")
    set(LUCI_INTERPRETER_PAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/pal/mcu")
elseif("${KERNELS}" STREQUAL "mcu")
    message(STATUS "ONERT_MICRO will use reference mcu kernels")
    set(LUCI_INTERPRETER_PAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/pal/mcu")
elseif("${KERNELS}" STREQUAL "cmsisnn")
    message(STATUS "ONERT_MICRO will use optimized cmsisnn kernels")
    set(LUCI_INTERPRETER_PAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/pal/cmsisnn")
elseif("${KERNELS}" STREQUAL "linux")
    message(STATUS "ONERT_MICRO will use optimized linux kernels")
    set(LUCI_INTERPRETER_PAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/pal/linux")
else()
    message(STATUS "Build onert-micro: FAILED (Non-existent kernel variable. Choose one of the following options: mcu, cmsisnn, linux)")
    return()
endif()

set(CMAKE_ARM_OPTIONS
        -DLUCI_INTERPRETER_STATIC=ON
        -DLUCI_STATIC=ON
        -DBUILD_CMSIS_NN_FUNCTIONS=ON
        -DTARGET_CPU=${TARGET_CPU}
        -DTARGET_ARCH=${TARGET_ARCH}
        "-DEXT_OVERLAY_DIR=${CMAKE_CURRENT_BINARY_DIR}/../../overlay"
        "-DFlatbuffers_DIR=${CMAKE_CURRENT_BINARY_DIR}/../../overlay/lib/cmake/flatbuffers"
        "-DCMAKE_TOOLCHAIN_FILE=${NNAS_PROJECT_SOURCE_DIR}/infra/nncc/cmake/buildtool/config/arm-none-eabi-gcc.cmake"
        "-DLUCI_INTERPRETER_PAL_DIR=${LUCI_INTERPRETER_PAL_DIR}"
        "-DNNAS_PROJECT_SOURCE_DIR=${NNAS_PROJECT_SOURCE_DIR}"
        "-DNNAS_EXTERNALS_DIR=${NNAS_EXTERNALS_DIR}"
        -DC_COMPILER=${ARM_C_COMPILER}
        -DCXX_COMPILER=${ARM_CXX_COMPILER}
        -DASM_COMPILER=${ARM_ASM_COMPILER}
        -DOBJCOPY=${ARM_OBJCOPY}
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DENABLE_TEST=OFF
        -DBUILD_GTEST=OFF
        "-DNNAS_ROOT=${NNAS_PROJECT_SOURCE_DIR}"
        -DENABLE_STRICT_BUILD=OFF
        "-DGENERATED_INCLUDE_DIR=${CMAKE_CURRENT_BINARY_DIR}/gen"
        )

if (GENERATE_KERNELS_LIST_FROM)
    set(GENERATED_KERNELS_LIST_PATH "${LUCI_INTERPRETER_PAL_DIR}/GeneratedKernelsToBuild.lst")
    list(APPEND CMAKE_ARM_OPTIONS "-DLUCI_INTERPRETER_KERNELS_BUILD_LIST=${GENERATED_KERNELS_LIST_PATH}")
endif ()

set(MICRO_ARM_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/standalone_arm")
file(MAKE_DIRECTORY "${MICRO_ARM_BUILD_DIR}")

set(MICRO_ARM_BUILD_DEPENDENCY "${MICRO_ARM_BUILD_DIR}/CMakeCache.txt")

add_custom_command(
        OUTPUT "${MICRO_ARM_BUILD_DEPENDENCY}"
        COMMAND "${CMAKE_COMMAND}" "${CMAKE_CURRENT_SOURCE_DIR}/standalone" ${CMAKE_ARM_OPTIONS}
        WORKING_DIRECTORY "${MICRO_ARM_BUILD_DIR}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/standalone/CMakeLists.txt"
        VERBATIM
)

add_custom_target(luci_interpreter_micro_arm_cmake DEPENDS "${MICRO_ARM_BUILD_DEPENDENCY}")

# Generate KernelsToBuild list from circle model
if (GENERATE_KERNELS_LIST_FROM)
    add_executable(generator_kernels_list_exec helpers/GenerateKernelsListHelper.cpp)

    target_link_libraries(generator_kernels_list_exec luci_micro_circle_reader)
    target_link_libraries(generator_kernels_list_exec luci_micro_circle_schema)

    target_include_directories(generator_kernels_list_exec PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/luci-interpreter/include")

    add_custom_target(
            generate_kernels_list ALL
            COMMAND generator_kernels_list_exec ${GENERATE_KERNELS_LIST_FROM} ${GENERATED_KERNELS_LIST_PATH}
            COMMENT "Generating KernelsToBuild list"
    )
    add_dependencies(generate_kernels_list luci_micro_circle_reader)
    add_dependencies(luci_interpreter_micro_arm_cmake generate_kernels_list)

endif ()

# To remove GENERATE_KERNELS_LIST_FROM and KERNELS variable from cmake cache
unset(GENERATE_KERNELS_LIST_FROM CACHE)
unset(KERNELS CACHE)

set(MICRO_ARM_BINARY "${MICRO_ARM_BUILD_DIR}/luci-interpreter/src/libluci_interpreter_micro.a")

add_custom_command(
        OUTPUT "${MICRO_ARM_BINARY}"
        COMMAND "${CMAKE_MAKE_PROGRAM}" luci_interpreter_micro -j ${CPU_COUNT}
        WORKING_DIRECTORY "${MICRO_ARM_BUILD_DIR}"
        DEPENDS luci_interpreter_micro_arm_cmake luci_micro_circle_schema
        VERBATIM
)

add_custom_target(luci_interpreter_micro_arm DEPENDS "${MICRO_ARM_BINARY}")

if (NOT DEFINED BUILD_TEST)
    return()
endif ()

#MBED OS QEMU build
nnas_find_package(MbedOSSource EXACT 6.15 QUIET)

if (NOT MbedOSSource_FOUND)
    message(STATUS "Skipping luci-micro: MbedOSSource not found")
    return()
endif ()

set(MBED_OS_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/tests/mbed-os")
file(MAKE_DIRECTORY "${MBED_OS_BUILD_DIR}")

set(MBED_OS_BUILD_DEPENDENCY "${MBED_OS_BUILD_DIR}/CMakeCache.txt")


set(ONERTMICRO_SRC_DIR "${NNAS_PROJECT_SOURCE_DIR}/onert-micro")

add_custom_command(
        OUTPUT "${MBED_OS_BUILD_DEPENDENCY}"
        COMMAND "${CMAKE_COMMAND}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/mbed-os"
        -DMICRO_ARM_BUILD_DIR=${MICRO_ARM_BUILD_DIR}
        -DMbedOSSource_DIR=${MbedOSSource_DIR}
        -DFlatBuffersSource_DIR=${FlatBuffersSource_DIR}
        -DONERTMICRO_SRC_DIR=${ONERTMICRO_SRC_DIR}
        WORKING_DIRECTORY "${MBED_OS_BUILD_DIR}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/tests/mbed-os/CMakeLists.txt"
        VERBATIM
)

add_custom_target(mbed_os_cmake DEPENDS "${MBED_OS_BUILD_DEPENDENCY}")

set(MBED_OS_BINARY "${MBED_OS_BUILD_DIR}/libmbed_os.a")

add_custom_command(
        OUTPUT "${MBED_OS_BINARY}"
        COMMAND "${CMAKE_MAKE_PROGRAM}" mbed_os -j ${CPU_COUNT}
        WORKING_DIRECTORY "${MBED_OS_BUILD_DIR}"
        DEPENDS mbed_os_cmake
        VERBATIM
)

add_custom_target(mbed_os_arm DEPENDS "${MBED_OS_BINARY}")

set(BUILD_TEST_BINARY "${MBED_OS_BUILD_DIR}/build_test.bin")

add_custom_command(
        OUTPUT "${BUILD_TEST_BINARY}"
        COMMAND "${CMAKE_MAKE_PROGRAM}" build_test -j ${CPU_COUNT}
        WORKING_DIRECTORY "${MBED_OS_BUILD_DIR}"
        DEPENDS mbed_os_arm "${CMAKE_CURRENT_SOURCE_DIR}/tests/mbed-os/main.cpp" ${MICRO_ARM_BINARY}
        VERBATIM
)
add_custom_target(onert_micro_build_test_arm DEPENDS "${BUILD_TEST_BINARY}")
