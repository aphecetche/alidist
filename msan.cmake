#
# A script to build a project in msan mode
#
# This script (named msan.cmake) should be executed from a build tree (can
# be empty) :
#
# cmake -S msan.cmake -DSOURCEDIR=... [ -DCMAKE_GENERATOR=... ]
#
# or just
#
# cmake -S msan.cmake
#
# assuming the environment variable SOURCEDIR is defined.
#
# In any case :
#
# * SOURCEDIR should point to the source directory of the project
#
# * CMAKE_GENERATOR (optional) should be either an env. or cmake variable (using
#   the -D syntax in that latter case) containing one of the valid generator
#   name known by the cmake program you are using. If not defined, make is used
#
#
# Note : if both an env. variable XXX and a cmake variable (-DXXX) exist, the
# cmake variable is used.
#
# Example usage (more complete) :
#
# mkdir build 
# cd build
# ctest -S msan.cmake -DSOURCEDIR=somepath/QualityControl -V -DCMAKE_GENERATOR=Ninja -DCTEST_PROJECT_NAME=QualityControl
#

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

# Setup for msan build
set(ENV{CXXFLAGS} "-fsanitize=memory")
set(ENV{LDFLAGS} "-fsanitize=memory")

set(CTEST_MEMORYCHECK_TYPE "MemorySanitizer")

ctest_start("Continuous")
ctest_configure()
ctest_build(CAPTURE_CMAKE_ERROR ERR)

if(ERR EQUAL -1)
  message(FATAL_ERROR "Build failed")
endif()

ctest_memcheck()

