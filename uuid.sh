package: UUID
version: v2.27.1
tag: alice/v2.27.1
source: https://github.com/alisw/uuid
build_requires:
 - "GCC-Toolchain:(?!osx)"
 - autotools
prefer_system: .*
prefer_system_check: |
  PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:$(for p in $(echo $LD_LIBRARY_PATH | tr ":" "\n"); do echo $p/pkgconfig; done | tr "\n" ":") pkg-config --libs uuid 
  if [ $? -ne 0 ]; then printf "libuuid not found\n"; exit 1; fi
---
rsync -av --delete --exclude "**/.git" $SOURCEDIR/ .
if [[ $AUTOTOOLS_ROOT == "" ]]  && which brew >/dev/null; then
  PATH=$PATH:`brew --prefix gettext`/bin
fi

perl -p -i -e 's/AM_GNU_GETTEXT_VERSION\(\[0\.18\.3\]\)/AM_GNU_GETTEXT_VERSION([0.18.2])/' configure.ac

[[ ${ARCHITECTURE:0:6} == ubuntu || ${ARCHITECTURE:0:3} == osx ]] && staticonly=1 || staticonly=0

autoreconf -ivf
./configure $($staticonly && echo --disable-shared) \
            --libdir=$INSTALLROOT/lib               \
            --prefix=$INSTALLROOT                   \
            --disable-all-programs                  \
            --disable-silent-rules                  \
            --disable-tls                           \
            --disable-rpath                         \
            --without-ncurses                       \
            --enable-libuuid
make ${JOBS:+-j$JOBS} libuuid.la
mkdir -p $INSTALLROOT/lib
cp -a .libs/libuuid.a* $INSTALLROOT/lib
if [[ ! $staticonly ]] ; then
  cp -a .libs/libuuid.so* $INSTALLROOT/lib
fi
mkdir -p $INSTALLROOT/include
make install-uuidincHEADERS
rm -rf $INSTALLROOT/man
