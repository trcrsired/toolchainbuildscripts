#!/bin/sh

rm /usr/local/lib64/libstdc++.so.6
rm /usr/local/lib64/libquadmath.so.0
rm /usr/local/lib64/libubsan.so.1
rm /usr/local/lib64/libgomp.so.1
rm /usr/local/lib64/libasan.so.7
rm /usr/local/lib64/libssp.so.0
rm /usr/local/lib64/liblsan.so.0
rm /usr/local/lib64/libtsan.so.1
rm /usr/local/lib64/libatomic.so.1
rm /usr/local/lib64/libhwasan.so.0
rm /usr/local/lib64/libitm.so.1

ln -s /usr/local/lib64/libstdc++.so.6.0.29 /usr/local/lib64/libstdc++.so.6
ln -s /usr/local/lib64/libubsan.so.1.0.0 /usr/local/lib64/libubsan.so.1
ln -s /usr/local/lib64/libgomp.so.1.0.0 /usr/local/lib64/libgomp.so.1
ln -s /usr/local/lib64/libasan.so.7.0.0 /usr/local/lib64/libasan.so.7
ln -s /usr/local/lib64/libssp.so.0.0.0 /usr/local/lib64/libssp.so.0
ln -s /usr/local/lib64/liblsan.so.0.0.0 /usr/local/lib64/liblsan.so.0
ln -s /usr/local/lib64/libtsan.so.1.0.0 /usr/local/lib64/libtsan.so.1
ln -s /usr/local/lib64/libatomic.so.1.2.0 /usr/local/lib64/libatomic.so.1
ln -s /usr/local/lib64/libhwasan.so.0.0.0 /usr/local/lib64/libhwasan.so.0
ln -s /usr/local/lib64/libitm.so.1.0.0 /usr/local/lib64/libitm.so.1