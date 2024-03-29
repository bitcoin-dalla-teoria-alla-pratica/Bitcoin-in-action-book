#!/bin/bash

if [ "$1" = 'MAINNET' ]
then
    VERSION_PREFIX_PB=80
    VERSION_PREFIX_ADDRESS=05
else
    VERSION_PREFIX_PB=EF
    VERSION_PREFIX_ADDRESS=C4
fi


for i in 1 2 3
do

  printf  "\n \e[31m ######### Create private key and public key ${i}  #########\e[0m\n\n"

  #private key
  openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -out private_key_$i.pem

  #private key bitcoin
  openssl ec -in private_key_$i.pem -outform DER|tail -c +8|head -c 32 |xxd -p -c 32 > btc_priv_$i.key

  #uncompressed private key
  printf "\n \n 🗝 Uncompressed private key WIF $i \n"
  C=`printf $VERSION_PREFIX_PB$(<btc_priv_$i.key) | xxd -r -p | base58 -c`
  printf $C"\n"
  printf $C > uncompressed_private_key_WIF_$i.txt

  #Compressed private key
  printf "\n \n 🗝 Compressed private key WIF $i \n"
  C=`printf $VERSION_PREFIX_PB$(<btc_priv_$i.key)"01" | xxd -r -p | base58 -c`
  printf $C"\n"
  printf $C > compressed_private_key_WIF_$i.txt

  #Uncompressed public key
  openssl ec -in private_key_$i.pem -pubout -outform DER|tail -c 65|xxd -p -c 65 > btc_pub_$i.key
  printf "\n \n 🔑 Uncompressed public key  $i \n"
  cat btc_pub_$i.key > uncompressed_public_key_$i.txt
  cat uncompressed_public_key_$i.txt

  #Compressed Address legacy
  printf "\n \n 🔑 Compressed Address legacy ${i}\n"
  ADDR_SHA=`printf $(cat uncompressed_public_key_$i.txt) | xxd -r -p | openssl sha256| sed 's/^.* //'`
  ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
  # echo $ADDR_RIPEMD160
  ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
  echo $ADDR > uncompressed_btc_address_$i.txt
  echo $ADDR

  #Check the last byte.
  U=`cat btc_pub_$i.key | cut -c 129-131`
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
  printf "\n \n 🔑 Compressed public key ${i}\n"
  cat btc_pub_$i.key | tr -d " \t\n\r"  | tail -c $((64*2)) | sed 's/.\{64\}/& /g'| awk '{print $1}'| sed -e 's/^/'$PREF/ > compressed_public_key_$i.txt
  cat compressed_public_key_$i.txt

  #Compressed Address
  printf "\n \n 🔑 Compressed Address ${i}\n"
  ADDR_SHA=`printf $(cat compressed_public_key_$i.txt) | xxd -r -p | openssl sha256| sed 's/^.* //'`
  ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
  # echo $ADDR_RIPEMD160
  ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
  echo $ADDR > compressed_btc_address_$i.txt
  echo $ADDR

done

    printf  "\n\e[42m ######### P2SH #########\e[49m\n\n"
    SCRIPT="5241"$(cat uncompressed_public_key_1.txt)"41"$(cat uncompressed_public_key_2.txt)"41"$(cat uncompressed_public_key_3.txt)"53AE"

    #With compressed public key
    #SCRIPT="5221"$(cat compressed_public_key_1.txt)"21"$(cat compressed_public_key_2.txt)"21"$(cat compressed_public_key_2.txt)"53AE"

    printf "\e[46m ---------- Redeem Script --------- \e[49m\n"
    printf $SCRIPT > redeem_script.txt
    cat redeem_script.txt

    ADDR_SHA=`printf $SCRIPT | xxd -r -p | openssl sha256| sed 's/^.* //'`
    ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
    printf $ADDR_RIPEMD160 > scriptPubKey.txt
    printf "\n \n\e[46m ---------- scriptPubKey --------- \e[49m\n"
    printf $ADDR_RIPEMD160

    #ADDRESS
    printf "\n \n\e[46m ---------- 🔑 ADDRESS P2SH️ --------- \e[49m\n"
    ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
    echo $ADDR > address_P2SH.txt
    echo $ADDR
