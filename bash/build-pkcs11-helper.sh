#!/bin/bash

./configure --prefix=/ --with-cygwin-native \
    --disable-crypto-engine-gnutls \
    --disable-crypto-engine-nss \
    PKG_CONFIG=true \
    OPENSSL_CFLAGS="-I${OpensslInstallDir}/include" \
    OPENSSL_LIBS="-L${OpensslInstallDir}/lib/libcrypto.lib"

make

cd lib/.libs
lib /def:libpkcs11-helper-1.dll.def \
		/name:libpkcs11-helper-1.dll \
		/out:pkcs11-helper.dll.lib
cd ../..

make install DESTDIR="${Pkcs11HelperInstallDir}"