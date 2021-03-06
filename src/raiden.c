/* This file is the part of the STM32 secure bootloader
 *
 * Raiden-CBC block cipher implementation based on original code developed by
 * Julio César Hernández Castro and Javier Polimón Olabarrieta
 * https://sourceforge.net/projects/raiden-cipher/
 *
 * Copyright ©2016 Dmitry Filimonchuk <dmitrystu[at]gmail[dot]com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdint.h>
#include "raiden.h"
#include "../config.h"

static uint32_t subkey[0x10];
static uint32_t CK[2];


inline static void __memcpy(void *dst, const void *src, uint32_t sz) {
    while(sz--) {
        *(uint8_t*)dst++ = *(uint8_t*)src++;
    }
}


static void raiden_encrypt_block(uint32_t *out, const uint32_t *in) {
    uint32_t b0 = in[0] ^ CK[0];
    uint32_t b1 = in[1] ^ CK[1];
    for (int i = 0; i < 16; i++ ) {
        uint32_t sk = subkey[i];
        b0 += ((sk+b1)<<9) ^ ((sk-b1)^((sk+b1)>>14));
        b1 += ((sk+b0)<<9) ^ ((sk-b0)^((sk+b0)>>14));
    }
    out[0] = CK[0] = b0;
    out[1] = CK[1] = b1;
}

static void raiden_decrypt_block(uint32_t *out, const uint32_t *in) {
    uint32_t b0 = in[0];
    uint32_t b1 = in[1];
    uint32_t i0 = b0;
    uint32_t i1 = b1;
    for (int i = 15; i >= 0; i--) {
        uint32_t sk = subkey[i];
        b1 -= ((sk+b0)<<9) ^ ((sk-b0)^((sk+b0)>>14));
        b0 -= ((sk+b1)<<9) ^ ((sk-b1)^((sk+b1)>>14));
    }
    out[0] = b0 ^ CK[0];
    out[1] = b1 ^ CK[1];
    CK[0] = i0;
    CK[1] = i1;
}



void raiden_init(const uint8_t *key) {
    uint32_t k[4];
    __memcpy(k, key, sizeof(k));
    for (int i = 0; i < 16; i++) {
        uint32_t sk = ((k[0]+k[1])+((k[2]+k[3])^(k[0]<<(k[2] & 0x1F))));
        k[i & 0x03] = sk;
        subkey[i] = sk;
    }
    CK[0] = DFU_AES_NONCE0;
    CK[1] = DFU_AES_NONCE1;
}

void raiden_encrypt(uint32_t *out, const uint32_t *in, int32_t bytes) {
    while(bytes > 0) {
        raiden_encrypt_block(out, in);
        out += 2;
        in += 2;
        bytes -= 0x08;
    }
}

void raiden_decrypt(uint32_t* out, const uint32_t *in, int32_t bytes) {
    while(bytes > 0) {
        raiden_decrypt_block(out, in);
        out += 2;
        in += 2;
        bytes -= 0x08;
    }
}




