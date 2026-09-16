#!/usr/bin/env bash

cp -r $IN/app.build-web/* ./
cp $IN/src.app.web/mobile-server.js ./

bun mobile-server.js
