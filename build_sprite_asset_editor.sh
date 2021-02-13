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
        -of=asset_editor \
        ../src/asset_editor.d ../src/mingine/editor_ui.d \
    && \
    echo "running..." && \
    ./asset_editor

popd >/dev/null
