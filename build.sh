#!/bin/bash

if [ "$#" -lt "1" ]; then
    echo "GSC CONFIG NOT PASSED"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

pushd ${SCRIPT_DIR}/builder
source build-py3.10-base.sh $1
popd

docker run --rm  -v ${SCRIPT_DIR}/scripts:/scripts -v ${SCRIPT_DIR}/data:/data -v ${SCRIPT_DIR}/builder:/builder -v ${SCRIPT_DIR}/server/keys:/keys \
    --entrypoint /bin/bash gsc-python3.10-base-gramine-poc /builder/crypt_and_sign.sh

pushd ${SCRIPT_DIR}/server
make
popd
