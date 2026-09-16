#!/usr/bin/env bash

source ~/.bashrc

cp -r $IN/src.backend/* ./

cargo build --release

cp target/release/backend $OUT/backend.build/
