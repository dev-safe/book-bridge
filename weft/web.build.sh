#!/usr/bin/env bash

source ~/.bashrc

cp -r $IN/src.web/* ./

bun install
bun run build

cp -r build/* $OUT/web.build/
