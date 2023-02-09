#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

docker run --rm --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${SCRIPT_DIR}/scripts/http_server_enc:/poc/run \
    -v ${SCRIPT_DIR}/data/encrypted:/poc/data \
    -v ${SCRIPT_DIR}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${SCRIPT_DIR}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${SCRIPT_DIR}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4433" --network="host" gsc-python3.10-base-gramine-poc
