#!/bin/bash

# this script removes "extra" files from Boost distribution archive to try and
# reduce its size. It creates a new zipped archive that may be diff-able for git.

if [ ${#@} -ne 1 ]; then
  echo >&2 "usage: $0 <tar-file>"
  exit 1
fi

set -e

FN="$1"

TEMPDIR=`mktemp -d`
function cleanup() {
  rm -r $TEMPDIR 
}
trap cleanup EXIT

tar -xf "$FN" -C $TEMPDIR
find $TEMPDIR -depth '(' -name examples -or -name  doc -or -name test ')' -print0 | xargs --null rm -r
# use gzip's --rsyncable option in hopes that this will let git diff versions
# of the tar archive
( cd $TEMPDIR ; tar -c * ) | gzip --rsyncable >${FN%.tar*}-stripped.tar.gz
