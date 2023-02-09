GRAMINEDIR ?= ../../..

ifeq ($(DEBUG),1)
GRAMINE_LOG_LEVEL = debug
CFLAGS += -O0 -ggdb3
else
GRAMINE_LOG_LEVEL = error
CFLAGS += -O2
endif

CFLAGS += -fPIE
LDFLAGS += -pie

.PHONY: dcap
dcap: secret_prov_server_dcap

CFLAGS += -Wall -std=c11 -I$(GRAMINEDIR)/tools/sgx/ra-tls \
          $(shell pkg-config --cflags mbedtls_gramine)
LDFLAGS += $(shell pkg-config --libs mbedtls_gramine)

# linker option --no-as-needed is required because SGX DCAP library (libsgx_dcap_quoteverify.so)
# does dlopen() instead of directly linking against libsgx_urts.so, and without this option
# compilers remove the "seemingly unused" libsgx_urts.so
secret_prov_server_dcap: src/secret_prov_server.c
	$(CC) $< $(CFLAGS) $(LDFLAGS) -Wl,--no-as-needed -lsgx_urts -lsecret_prov_verify_dcap -pthread -o $@


.PHONY: clean
clean:
	$(RM) -r secret_prov_server_dcap
