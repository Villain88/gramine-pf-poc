#!/bin/bash

rm scripts/crypted.py
rm scripts/crypted.py_

make clean
gramine-sgx-pf-crypt encrypt -w server/keys/wrap-key2 -i scripts/malicious.py -o scripts/crypted.py
mv scripts/crypted.py scripts/crypted.py_
gramine-sgx-pf-crypt encrypt -w server/keys/wrap-key -i scripts/helloworld.py -o scripts/crypted.py
make SGX=1

pushd server
make
popd
