#!/bin/bash

if [ "$1" = 'MAINNET' ]
then
    VERSION_PREFIX_PB=80
    VERSION_PREFIX_ADDRESS=00
else
    VERSION_PREFIX_PB=EF
    VERSION_PREFIX_ADDRESS=6F
fi

  printf  "\n \e[31m ######### Create private key and public key  #########\e[0m\n\n"

  #private key
  openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -out private_key_1.pem

  #private key bitcoin
  openssl ec -in private_key_1.pem -outform DER|tail -c +8|head -c 32 |xxd -p -c 32 > btc_priv_1.key

  #uncompressed_private_key_WIF_
  printf "\n \n 🗝 Uncompressed private key WIF \n"
  C=`printf $VERSION_PREFIX_PB$(<btc_priv_1.key) | xxd -r -p | base58 -c`
  printf $C"\n"
  printf $C > uncompressed_private_key_WIF_1.txt

  #Compressed private key
  printf "\n \n 🗝 Compressed private key WIF \n"
  C=`printf $VERSION_PREFIX_PB$(<btc_priv_1.key)"01" | xxd -r -p | base58 -c`
  printf $C"\n"
  printf $C > compressed_private_key_WIF_1.txt

  #Uncompressed public key
  openssl ec -in private_key_1.pem -pubout -outform DER|tail -c 65|xxd -p -c 65 > btc_pub_1.key
  printf "\n \n 🔑 Uncompressed public key \n"
  cat btc_pub_1.key > uncompressed_public_key_1.txt
  cat uncompressed_public_key_1.txt

  #Uncompressed Address legacy
  printf "\n \n 🔑 Uncompressed Address legacy \n"
  ADDR_SHA=`printf $(cat uncompressed_public_key_1.txt) | xxd -r -p | openssl sha256| sed 's/^.* //'`
  ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
  # echo $ADDR_RIPEMD160
  ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
  echo $ADDR > uncompressed_btc_address_1.txt
  echo $ADDR

  #Check the last byte.
  U=`cat btc_pub_1.key | cut -c 129-131`
  U=`echo "$U" | tr '[:lower:]' '[:upper:]'`
  U=`echo "ibase=16; $U" | bc`

  if [ $(($U%2)) -eq 0 ];
  then
  #key even
      PREF=02
  else
  #key odd
      PREF=03
  fi

  #Compressed public key
  printf "\n \n 🔑 Compressed public key \n"
  cat btc_pub_1.key | tr -d " \t\n\r"  | tail -c $((64*2)) | sed 's/.\{64\}/& /g'| awk '{print $1}'| sed -e 's/^/'$PREF/ > compressed_public_key_1.txt
  cat compressed_public_key_1.txt

  #Compressed Address legacy
  printf "\n \n 🔑 Compressed Address legacy \n"
  ADDR_SHA=`printf $(cat compressed_public_key_1.txt) | xxd -r -p | openssl sha256| sed 's/^.* //'`
  ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
  ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
  echo $ADDR > compressed_btc_address_1.txt
  echo $ADDR
