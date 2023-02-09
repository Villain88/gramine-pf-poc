#!/bin/sh -ex

gramine-sgx-pf-crypt encrypt -w /keys/wrap-key2 -i /scripts/malicious.py -o /poc/run/entrypoint.py
mkdir -p /scripts/malicious_enc && mv /poc/run/entrypoint.py /scripts/malicious_enc/

gramine-sgx-pf-crypt encrypt -w /keys/wrap-key -i /scripts/http_server.py -o /poc/run/entrypoint.py
mkdir -p /scripts/http_server_enc && mv /poc/run/entrypoint.py /scripts/http_server_enc/

rm -rf /data/encrypted
gramine-sgx-pf-crypt encrypt -w /keys/wrap-key -i /data/ -o /poc/data
mkdir -p /data/encrypted && mv /poc/data/* /data/encrypted/

export PYTHONPATH="\${PYTHONPATH}:$(find /gramine/meson_build_output/lib -type d -path '*/site-packages')"
export PKG_CONFIG_PATH="\${PKG_CONFIG_PATH}:$(find /gramine/meson_build_output/lib -type d -path '*/pkgconfig')"

openssl genrsa -3 -out /enclave-key.pem 3072

cp /scripts/http_server.py /poc/run/entrypoint.py
mkdir -p /scripts/http_server_manifest
gramine-sgx-sign -k "/enclave-key.pem" -m "/gramine/app_files/entrypoint.manifest" -o "/scripts/http_server_manifest/entrypoint.manifest.sgx" -s "/scripts/http_server_manifest/entrypoint.sig"