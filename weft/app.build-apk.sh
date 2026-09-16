#!/usr/bin/env bash
source ~/.bashrc

cp -r $IN/src.app/* ./

flutter build apk

cp -r build/apk/* $OUT/app.build-apk/
