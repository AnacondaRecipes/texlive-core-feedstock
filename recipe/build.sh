#! /bin/bash

# From: https://github.com/TeX-Live/texlive-source/blob/master/Buil
unset TEXMFCNF; export TEXMFCNF
LANG=C; export LANG
[[ -d "${PREFIX}"/texmf ]] || mkdir -p "${PREFIX}"/texmf
./configure --help

# kpathsea scans the texmf.cnf file to set up its hardcoded paths, so set them
# up before building. It doesn't seem to handle multivalued TEXMFCNF entries,
# so we patch that up after install.

declare -a CONFIG_EXTRA
if [[ ${target_platform} =~ .*ppc.* ]]; then
  # luajit is incompatible with powerpc.
  CONFIG_EXTRA+=(-disable-luajittex)
fi

if [[ ${target_platform} =~ .*linux.* ]]; then
  # -O2 results in:
  # FAIL: mplibdir/mptraptest.test
  # FAIL: pdftexdir/pdftosrc.test
  # .. so (sorry!)
  export CFLAGS="${CFLAGS} -O0 -ggdb"
  export CXXFLAGS="${CXXFLAGS} -O0 -ggdb"
  CONFIG_EXTRA+=(--enable-debug)
else
  CONFIG_EXTRA+=(--disable-debug)
fi

mv $SRC_DIR/texk/kpathsea/texmf.cnf tmp.cnf
sed \
    -e "s|TEXMFROOT =.*|TEXMFROOT = $PREFIX/share/texlive|" \
    -e "s|TEXMFLOCAL =.*|TEXMFLOCAL = $PREFIX/share/texlive/texmf-local|" \
    -e "/^TEXMFCNF/,/^}/d" \
    -e "s|%TEXMFCNF =.*|TEXMFCNF = $PREFIX/share/texlive/texmf-dist/web2c|" \
    <tmp.cnf >$SRC_DIR/texk/kpathsea/texmf.cnf
rm -f tmp.cnf

# We need to package graphite2 to be able to use it harfbuzz.
# Using our cairo breaks the recipe and `mpfr` is not found triggering the library from TL tree.

mkdir build || true
pushd build
  ../configure --prefix="${PREFIX}" \
               --host=${HOST} \
               --build=${BUILD} \
               --datarootdir="${PREFIX}"/share/texlive \
               --disable-all-pkgs \
               --disable-native-texlive-build \
               --disable-ipc \
               --disable-debug \
               --disable-dependency-tracking \
               --disable-mf \
               --disable-pmp \
               --disable-upmp \
               --disable-aleph \
               --disable-eptex \
               --disable-euptex \
               --disable-luatex \
               --disable-luajittex \
               --disable-uptex \
               --enable-web2c \
               --enable-silent-rules \
               --enable-tex \
               --enable-etex \
               --enable-pdftex \
               --enable-xetex \
               --enable-web-progs \
               --enable-texlive \
               --enable-dvipdfm-x \
               --with-system-cairo \
               --with-system-freetype2 \
               --with-system-gmp \
               --with-system-graphite2 \
               --with-system-harfbuzz \
               --with-system-icu \
               --with-system-libpng \
               --with-system-mpfr \
               --with-system-pixman \
               --with-system-poppler \
               --with-system-zlib \
               --without-x \
               "${CONFIG_EXTRA[@]}" || { cat config.log ; exit 1 ; }
  # There is a race-condition in the build system.
  make -j${CPU_COUNT} ${VERBOSE_AT} || make -j1 ${VERBOSE_AT}
  LC_ALL=C make check ${VERBOSE_AT}
  make install -j${CPU_COUNT}
popd

# Remove info and man pages.
rm -rf "${PREFIX}"/share/man
rm -rf "${PREFIX}"/share/texlive/info

mv "${PREFIX}"/share/texlive/texmf-dist/web2c/texmf.cnf tmp.cnf
sed \
    -e "s|TEXMFCNF =.*|TEXMFCNF = {$PREFIX/share/texlive/texmf-local/web2c, $PREFIX/share/texlive/texmf-dist/web2c}|" \
    <tmp.cnf >$PREFIX/share/texlive/texmf-dist/web2c/texmf.cnf
rm -f tmp.cnf

# Create symlinks for pdflatex and latex
pushd "${PREFIX}"/bin
  ln -s pdftex pdflatex
  ln -s pdftex latex
popd
