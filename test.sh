#!/bin/sh

for file in test/*; do
  if test -f $file; then
    ./$file $(pwd) || exit 1
  fi
done
