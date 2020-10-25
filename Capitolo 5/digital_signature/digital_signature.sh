#!/bin/sh
echo "Don't trust, verify" > msg.txt
#create private key
openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -noout -out private.pem
printf  "\n\e[101m ######### Private Key #########\e[49m\n"
cat private.pem

#public key derivation
openssl ec -in private.pem -pubout -out public.pem
printf  "\n\e[42m ######### Public Key #########\e[49m\n"
cat public.pem

#create signature
openssl dgst -sha256 -sign private.pem msg.txt > signature.bin

printf  "\n\e[106m ######### Signature in hex #########\e[49m\n"
xxd -p signature.bin |  tr -d '\n'  | awk '{print $1}'

#check signature
printf  "\n\e[42m ######### Verify the signature #########\e[49m\n"
openssl dgst -sha256 -verify public.pem -signature signature.bin msg.txt
