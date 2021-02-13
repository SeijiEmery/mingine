#!/usr/bin/env bash

if [ ! -e build/libs/ ]
then
    echo "building libs..."
    ./build_libs.sh
fi
if [ ! -e build ]
then
    mkdir build
fi
pushd build >/dev/null

    echo "building..." && \
    dmd -I=libs/raylib/include/ libs/raylib/lib/libdraylib.a -L=-lraylib \
        -of=spritestack_test \
        ../src/spritestack_test.d ../src/mingine/editor_ui.d \
    && \
    echo "running..." && \
    ./spritestack_test

popd >/dev/null
