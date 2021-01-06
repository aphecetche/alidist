package: DebugGUI
version: "v0.3.1"
tag: "v0.3.1"
requires:
  - "GCC-Toolchain:(?!osx)"
  - GLFW
  - FreeType
  - libuv
build_requires:
  - capstone
  - CMake
  - alibuild-recipe-tools
source: https://github.com/AliceO2Group/DebugGUI
---

function assertPackage() {
  rootvar=$1_ROOT
  pkgname=$2
  libname=${3:-$pkgname}
  b=$(eval echo \$$rootvar)
  if [[ ! -d "$b" ]]; then
    # rootvar is not a valid path or is empty, try to find one using either
    # brew or pkg-config
    if command -v brew &> /dev/null; then
      pre=$(brew --prefix $pkgname 2> /dev/null)
      [[ -d "$pre" ]] && eval $rootvar=$pre && LIBS="$LIBS -L$pre/lib -l$libname"
      echo "LIBS=$LIBS"
    elif command -v pkg-config &> /dev/null; then
      if [[ ! -d "$b" ]]; then
        eval $rootvar=$(pkg-config --variable=prefix $pkgname 2> /dev/null) && LIBS="$LIBS $(pkg-config --libs $pkgname 2> /dev/null)"
      fi
    fi
    else
      # rootvar is valid, use it simply
      LIBS="$LIBS -L$b/lib -l$libname"
  fi
}

assertPackage GLFW glfw3 glfw
assertPackage LIBUV libuv uv
assertPackage FREETYPE freetype2 freetype
assertPackage CAPSTONE capstone

case $ARCHITECTURE in
    osx*)
      EXTRA_LIBS="-framework CoreFoundation -framework AppKit"
      DEFINES="-DNO_PARALLEL_SORT"
    ;;
    *) 
      DEFINES="-DIMGUI_IMPL_OPENGL_LOADER_GL3W -DTRACY_NO_FILESELECTOR"
      if command -v pkg-config &> /dev/null; then
        EXTRA_LIBS=$(pkg-config --libs x11 gl)
      else
        EXTRA_LIBS="-lGL"
      fi
      ! ld -ltbb -o /dev/null 2>/dev/null || EXTRA_LIBS="${EXTRA_LIBS} -ltbb" 
      if command -v spack; then
        # try to get tbb from spack
        if spack find intel-tbb &> /dev/null; then
          EXTRA_LIBS="${EXTRA_LIBS} -L$(spack find --format \"{prefix}\" intel-tbb)/lib -ltbb"
        fi
      fi
    ;;
esac

LIBS="$LIBS $EXTRA_LIBS -ldl -lpthread"

# Use ninja if in devel mode, ninja is found and DISABLE_NINJA is not 1
if [[ ! $CMAKE_GENERATOR && $DISABLE_NINJA != 1 && $DEVEL_SOURCES != $SOURCEDIR ]]; then
  NINJA_BIN=ninja-build
  type "$NINJA_BIN" &> /dev/null || NINJA_BIN=ninja
  type "$NINJA_BIN" &> /dev/null || NINJA_BIN=
  [[ $NINJA_BIN ]] && CMAKE_GENERATOR=Ninja || true
  unset NINJA_BIN
fi

# build the tracy profiler
rsync -av $SOURCEDIR/tracy/ tracy/
pushd tracy/profiler/build/unix
  make \
    LIBS="$LIBS" \
    DEFINES="$DEFINES" \
    INCLUDES="-I$CAPSTONE_ROOT/include -I$SOURCEDIR/tracy/imgui -I$SOURCEDIR/tracy -I$SOURCEDIR/tracy/profiler/libs/gl3w ${FREETYPE_ROOT:+-I$FREETYPE_ROOT/include/freetype2} -I${GLFW_ROOT:+$GLFW_ROOT/include}"
popd
mkdir -p $INSTALLROOT/{include/tracy,bin}
cp tracy/profiler/build/unix/Tracy-debug $INSTALLROOT/bin/tracy-profiler
cp tracy/*.{h,hpp,cpp} $INSTALLROOT/include/tracy
cp -r tracy/{common,client,libbacktrace} $INSTALLROOT/include/tracy/

cmake $SOURCEDIR                          \
      -DCMAKE_INSTALL_PREFIX=$INSTALLROOT \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

cp ${BUILDDIR}/compile_commands.json ${INSTALLROOT}
cmake --build . -- ${JOBS+-j $JOBS} install

#ModuleFile
mkdir -p etc/modulefiles
alibuild-generate-module --bin --lib > etc/modulefiles/$PKGNAME
mkdir -p $INSTALLROOT/etc/modulefiles && rsync -a --delete etc/modulefiles/ $INSTALLROOT/etc/modulefiles
