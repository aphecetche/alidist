#
#
# A script to build a project in address sanitizing mode
#
# This script (named asan.cmake) should be executed from a build tree (can
# be empty) :
#
# ctest -S asan.cmake -DSOURCEDIR=... [ -DCMAKE_GENERATOR=... ]
#
# or just
#
# ctest -S asan.cmake
#
# assuming the environment variable SOURCEDIR is defined.
#
# In any case a correct _build_ environment must be defined first, and then :
#
# * SOURCEDIR should point to the source directory of the project
#
# * CMAKE_GENERATOR (optional) should be either an env. or cmake variable (using
#   the -D syntax in that latter case) containing one of the valid generator
#   name known by the cmake program you are using. If not defined, Ninja is used
#
# In aliBuild world, the easiest way to get a correct build env. is to do
#
# WORK_DIR=/path/to/sw/ && source $WORK_DIR/[PACKAGE]/latest/etc/profile.d/init.sh
#
# where [PACKAGE] is the package you are trying to get address sanitizing for.
#
# Note : if both an env. variable XXX and a cmake variable (-DXXX) exist, the
# cmake variable is used.
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
#set(CTEST_PROJECT_NAME TOTO)
set(CTEST_SOURCE_DIRECTORY ${SOURCEDIR})
set(CTEST_BINARY_DIRECTORY .)
set(CTEST_USE_LAUNCHERS 1)

# Setup for asan build
set(ENV{CXXFLAGS} "-fsanitize=undefined -g -fno-omit-frame-pointer -fno-sanitize=vptr")
set(ENV{LDFLAGS} "-fsanitize=undefined -fno-sanitize=vptr")


ctest_start("Continuous")
ctest_configure()
ctest_build(CAPTURE_CMAKE_ERROR ERR)

if(ERR EQUAL -1)
  message(FATAL_ERROR "Build failed")
endif()

ctest_test(INCLUDE_LABEL mch INCLUDE UserLogic)

# set(CTEST_MEMORYCHECK_TYPE "AddressSanitizer")
#
# ctest_memcheck(INCLUDE_LABEL mch INCLUDE UserLogic)

set(CTEST_MEMORYCHECK_TYPE "UndefinedBehaviorSanitizer")

ctest_memcheck(INCLUDE_LABEL mch INCLUDE UserLogic)
