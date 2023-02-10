#!/bin/sh -ex
export PYTHONPATH="\${PYTHONPATH}:$(find /gramine/meson_build_output/lib -type d -path '*/site-packages')"
export PKG_CONFIG_PATH="\${PKG_CONFIG_PATH}:$(find /gramine/meson_build_output/lib -type d -path '*/pkgconfig')"

openssl genrsa -3 -out /enclave-key.pem 3072

cp /scripts/http_server.py /poc/run/entrypoint.py
mkdir -p /scripts/http_server_manifest
gramine-sgx-sign -k "/enclave-key.pem" -m "/gramine/app_files/entrypoint.manifest" -o "/scripts/http_server_manifest/entrypoint.manifest.sgx" -s "/scripts/http_server_manifest/entrypoint.sig"
