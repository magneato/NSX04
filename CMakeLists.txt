cmake_minimum_required(VERSION 3.20)
project(NSX4004 LANGUAGES ASM_NASM)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Output directories (align with existing scripts)
set(OUT_DIR   "${CMAKE_SOURCE_DIR}/output")
set(BINS_DIR  "${OUT_DIR}/bins")
set(ROMS_DIR  "${OUT_DIR}/roms")
add_custom_target(make_out_dir
  COMMAND ${CMAKE_COMMAND} -E make_directory ${BINS_DIR}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${ROMS_DIR}
)

# -----------------------
# Python assembler + ROMs
# -----------------------
set(ASM4004_SCRIPT ${CMAKE_SOURCE_DIR}/scripts/asm4004_lite.py)

set(ROM_SOURCES
  ${CMAKE_SOURCE_DIR}/src/asm/tran4004.asm
  ${CMAKE_SOURCE_DIR}/src/asm/infr4004.asm)

set(ROM_OUTPUTS)
foreach(SRC ${ROM_SOURCES})
  get_filename_component(NAME_WE ${SRC} NAME_WE)
  string(TOUPPER ${NAME_WE} NAME_UP)
  set(OUT_FILE "${ROMS_DIR}/${NAME_UP}.ROM")
  add_custom_command(
    OUTPUT ${OUT_FILE}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${ROMS_DIR}
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT} ${SRC} -q -o ${OUT_FILE}
    DEPENDS ${ASM4004_SCRIPT} ${SRC}
    COMMENT "Assembling ${OUT_FILE} from ${SRC} using asm4004_lite.py"
    VERBATIM
  )
  list(APPEND ROM_OUTPUTS ${OUT_FILE})
endforeach()
add_custom_target(roms ALL DEPENDS ${ROM_OUTPUTS})
add_dependencies(roms make_out_dir)

# -----------------------
# NASM 8086 (.COM)
# -----------------------
find_program(NASM_EXECUTABLE nasm REQUIRED)

set(DUCKER_SRC ${CMAKE_SOURCE_DIR}/src/asm/ducker.asm)
set(DUCKER_COM ${BINS_DIR}/DUCKER.COM)
add_custom_command(
  OUTPUT ${DUCKER_COM}
  COMMAND ${CMAKE_COMMAND} -E make_directory ${BINS_DIR}
  COMMAND ${NASM_EXECUTABLE} -f bin -o ${DUCKER_COM} ${DUCKER_SRC}
  DEPENDS ${DUCKER_SRC}
  COMMENT "Assembling DUCKER.COM from ${DUCKER_SRC}"
  VERBATIM
)
add_custom_target(ducker ALL DEPENDS ${DUCKER_COM})

# -----------------------
# CTest hooks
# -----------------------
include(CTest)
enable_testing()
if (BUILD_TESTING)
  set(TEST_ARTIFACT_DIR "${CMAKE_BINARY_DIR}/tests")
  file(MAKE_DIRECTORY ${TEST_ARTIFACT_DIR})

  add_test(NAME asm4004_whitespace
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT}
            ${CMAKE_SOURCE_DIR}/test/asmcases/whitespace.asm
            -q -o ${TEST_ARTIFACT_DIR}/whitespace.rom)
  add_test(NAME asm4004_multidigit
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT}
            ${CMAKE_SOURCE_DIR}/test/asmcases/multidigit_registers.asm
            -q -o ${TEST_ARTIFACT_DIR}/multidigit.rom)
  add_test(NAME asm4004_mixedcase
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT}
            ${CMAKE_SOURCE_DIR}/test/asmcases/mixedcase_labels.asm
            -q -o ${TEST_ARTIFACT_DIR}/mixedcase.rom)
  add_test(NAME asm4004_tran4004
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT}
            ${CMAKE_SOURCE_DIR}/src/asm/tran4004.asm
            -q -o ${TEST_ARTIFACT_DIR}/TRAN4004.rom)
  add_test(NAME asm4004_infr4004
    COMMAND ${Python3_EXECUTABLE} ${ASM4004_SCRIPT}
            ${CMAKE_SOURCE_DIR}/src/asm/infr4004.asm
            -q -o ${TEST_ARTIFACT_DIR}/INFR4004.rom)
endif()

# Summary
message(STATUS "Python assembler script: ${ASM4004_SCRIPT}")
message(STATUS ".COM output: ${DUCKER_COM}")
message(STATUS "ROM outputs: ${ROM_OUTPUTS}")
