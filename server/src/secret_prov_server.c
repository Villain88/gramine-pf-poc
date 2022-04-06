/* SPDX-License-Identifier: LGPL-3.0-or-later */
/* Copyright (C) 2020 Intel Labs */

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "secret_prov.h"

#define WRAP_KEY_SIZE     16

static pthread_mutex_t g_print_lock;
char g_secret_pf_key_hex[WRAP_KEY_SIZE * 2 + 1];

static void hexdump_mem(const void* data, size_t size) {
    uint8_t* ptr = (uint8_t*)data;
    for (size_t i = 0; i < size; i++)
        printf("%02x", ptr[i]);
    printf("\n");
}

/* our own callback to verify SGX measurements during TLS handshake */
static int verify_measurements_callback(const char* mrenclave, const char* mrsigner,
                                        const char* isv_prod_id, const char* isv_svn) {
    assert(mrenclave && mrsigner && isv_prod_id && isv_svn);

    pthread_mutex_lock(&g_print_lock);
    puts("Received the following measurements from the client:");
    printf("  - MRENCLAVE:   "); hexdump_mem(mrenclave, 32);
    printf("  - MRSIGNER:    "); hexdump_mem(mrsigner, 32);
    printf("  - ISV_PROD_ID: %hu\n", *((uint16_t*)isv_prod_id));
    printf("  - ISV_SVN:     %hu\n", *((uint16_t*)isv_svn));
    printf("\n");
    pthread_mutex_unlock(&g_print_lock);

    return 0;
}

/* this callback is called in a new thread associated with a client; be careful to make this code
 * thread-local and/or thread-safe */
static int communicate_with_client_callback(struct ra_tls_ctx* ctx) {

    /* if we reached this callback, the first secret was sent successfully */
    printf("--- Sent secret = '%s' ---\n", g_secret_pf_key_hex);

    secret_provision_close(ctx);
    return 0;
}

int main(int argc, char** argv) {
    int ret;

    ret = pthread_mutex_init(&g_print_lock, NULL);
    if (ret < 0)
        return ret;
    
    if (argc < 2) {
        fprintf(stderr, "Key filename should be passed\n");
        return 1;
    }

    char *keyfile = argv[1];
    printf("--- Reading the master key for protected files from <%s> ---\n", keyfile);
    int fd = open(keyfile, O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "[error] cannot open <%s>'\n", keyfile);
        return 1;
    }

    char buf[WRAP_KEY_SIZE + 1] = {0}; /* +1 is to detect if file is not bigger than expected */
    ssize_t bytes_read = 0;
    while (1) {
        ssize_t ret = read(fd, buf + bytes_read, sizeof(buf) - bytes_read);
        if (ret > 0) {
            bytes_read += ret;
        } else if (ret == 0) {
            /* end of file */
            break;
        } else if (errno == EAGAIN || errno == EINTR) {
            continue;
        } else {
            fprintf(stderr, "[error] cannot read <%s>\n", keyfile);
            close(fd);
            return 1;
        }
    }

    ret = close(fd);
    if (ret < 0) {
        fprintf(stderr, "[error] cannot close <%s>\n", keyfile);
        return 1;
    }

    if (bytes_read != WRAP_KEY_SIZE) {
        fprintf(stderr, "[error] encryption key from <%s> is not 16B in size\n", keyfile);
        return 1;
    }

    uint8_t* ptr = (uint8_t*)buf;
    for (size_t i = 0; i < bytes_read; i++)
        sprintf(&g_secret_pf_key_hex[i * 2], "%02x", ptr[i]);

    puts("--- Starting the Secret Provisioning server on port 4433 ---");
    ret = secret_provision_start_server((uint8_t*)g_secret_pf_key_hex, sizeof(g_secret_pf_key_hex),
                                        "4433", "certs/cert.pem", "certs/plainkey.pem",
                                        verify_measurements_callback,
                                        communicate_with_client_callback);
    if (ret < 0) {
        fprintf(stderr, "[error] secret_provision_start_server() returned %d\n", ret);
        return 1;
    }

    pthread_mutex_destroy(&g_print_lock);
    return 0;
}
