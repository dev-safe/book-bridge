#!/usr/bin/env bash
source ~/.bashrc

cp -r $IN/src.app/* ./

flutter build web

cp -r build/web/* $OUT/app.build-web/
