#!/bin/sh -ex

if [ "$#" -lt "1" ]; then
    echo "GSC CONFIG NOT PASSED"
    exit 1
fi

GSC_FIXED_COMMIT="v1.3.1"
BASE_IMAGE_NAME="python3.10-base-gramine-poc"

docker rmi gsc-${BASE_IMAGE_NAME} -f
docker rmi gsc-${BASE_IMAGE_NAME}-unsigned -f
docker rmi ${BASE_IMAGE_NAME} -f

docker build -t ${BASE_IMAGE_NAME} --rm .

rm -f enclave-key.pem
openssl genrsa -3 -out enclave-key.pem 3072

rm -rf ./gsc
git clone https://github.com/gramineproject/gsc && cd gsc && git reset --hard "${GSC_FIXED_COMMIT}"

./gsc build ${BASE_IMAGE_NAME} ../python3.10-base.manifest -c $1
./gsc sign-image ${BASE_IMAGE_NAME} ../enclave-key.pem -c $1
