#!/usr/bin/env bash

if [ ! -e build/libs/raylib ]
then
    mkdir -p build/libs/raylib
fi

pushd build/libs/raylib > /dev/null
    if [ ! -e lib ]
    then
        mkdir lib
    fi
    echo "building draylib.a + raylib/include"
    dmd -lib -of=lib/libdraylib.a -Hd=include -L=-lraylib ../../../ext/raylib-d/source/*.d
popd >/dev/null
