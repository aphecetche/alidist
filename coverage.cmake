#
# A script to build a project in coverage mode
#
# This script (named coverage.cmake) should be executed from a build tree (can
# be empty) :
#
# cmake -S coverage.cmake -DSOURCEDIR=... [ -DCMAKE_GENERATOR=... ]
#
# or just
#
# cmake -S coverage.cmake
#
# assuming the environment variable SOURCEDIR is defined.
#
# In any case :
#
# * SOURCEDIR should point to the source directory of the project
#
# * CMAKE_GENERATOR (optional) should be either an env. or cmake variable (using
#   the -D syntax in that latter case) containing one of the valid generator
#   name known by the cmake program you are using. If not defined, Ninja is used
#
#
# Note : if both an env. variable XXX and a cmake variable (-DXXX) exist, the
# cmake variable is used.

# Ensure we have a sourcedir to work with
if(NOT SOURCEDIR)
  if(NOT DEFINED ENV{SOURCEDIR})
    message(FATAL_ERROR "Should define SOURCEDIR")
  else()
    set(SOURCEDIR $ENV{SOURCEDIR})
  endif()
endif()

get_filename_component(DIR ${SOURCEDIR} ABSOLUTE)
if(NOT EXISTS ${DIR})
  message(FATAL_ERROR "Source directory ${DIR} does not exist")
endif()

# Ensure we define the generator to be used
if(CMAKE_GENERATOR)
  set(CTEST_CMAKE_GENERATOR ${CMAKE_GENERATOR})
elseif(DEFINED ENV{CMAKE_GENERATOR})
  set(CTEST_CMAKE_GENERATOR $ENV{CMAKE_GENERATOR})
else()
  message(
    STATUS "CMAKE_GENERATOR not defined, using Unix CMakefiles by default")
  set(CTEST_CMAKE_GENERATOR "Unix Makefiles")
endif()

# Set source and build directories
set(CTEST_SOURCE_DIRECTORY ${SOURCEDIR})
set(CTEST_BINARY_DIRECTORY .)
set(CTEST_USE_LAUNCHERS 1)

# Setup for coverage build
set(ENV{CXXFLAGS} "--coverage -g -O0")
set(CTEST_COVERAGE_COMMAND "gcov")

ctest_start("Continuous")
ctest_configure()
ctest_build(CAPTURE_CMAKE_ERROR ERR)

if(ERR EQUAL -1)
  message(FATAL_ERROR "Build failed")
endif()

ctest_test()
ctest_coverage()

# After the coverage files have been generated, process them
# with lcov and genhtml (if available)

find_program(LCOV_EXECUTABLE lcov)
find_program(GENHTML_EXECUTABLE genhtml)

set(COVERAGE_INFO_FILE coverage.info)
set(HTML_OUTPUT_DIRECTORY "${CTEST_BINARY_DIRECTORY}/coverage-html")

list(APPEND EXCLUDE_LIST
            '*/usr/*'
            '*/boost/*'
            '*/ROOT/*'
            '*/FairRoot/*'
            '*/G__*Dict*')

if(LCOV_EXECUTABLE)
  execute_process(COMMAND ${LCOV_EXECUTABLE}
                          "--directory"
                          "${CTEST_BINARY_DIRECTORY}"
                          "--base-directory"
                          "${CTEST_SOURCE_DIRECTORY}"
                          "--capture"
                          "--no-external"
                          "--quiet"
                          "--output-file"
                          "${COVERAGE_INFO_FILE}")

  foreach(EX in EXCLUDE_LIST)
    set(cmd
        ${LCOV_EXECUTABLE}
        "--remove"
        "${COVERAGE_INFO_FILE}"
        "${EX}"
        "--output-file"
        "${COVERAGE_INFO_FILE}")
    message(STATUS "cmd=${cmd}")
    execute_process(COMMAND ${cmd})
  endforeach()

  # the part below generates a local html report

  if(GENHTML_EXECUTABLE)
    execute_process(COMMAND ${GENHTML_EXECUTABLE}
                            "${COVERAGE_INFO_FILE}"
                            "--ignore-errors"
                            "source"
                            "--output-directory"
                            "${HTML_OUTPUT_DIRECTORY}")
  else()
    message(STATUS "genhtml command not found : not using it")
  endif()
else()
  message(STATUS "lcov command not found : not using it")
endif()
