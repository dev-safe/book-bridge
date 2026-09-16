#!/usr/bin/env bash

source ~/.bashrc

cp -r $IN/web.build/* ./

for i in {1..10}; do
    bun .

    status=$?
    if [ $status -eq 0 ]; then
        break
    fi
    echo "Attempt $i failed with exit code $status. Retrying..."
    sleep 5
done
if [ $status -ne 0 ]; then
    echo "Command failed 10 times. Exiting with status $status."
    exit $status
fi
