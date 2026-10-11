#!/usr/bin/env bash

mkdir -p ./curr
cp -r $IN/app.build-web/* ./curr/
cp -r $IN/app.build-web/* ./
cp $IN/src.app.web/mobile-server.js ./

bun mobile-server.js
