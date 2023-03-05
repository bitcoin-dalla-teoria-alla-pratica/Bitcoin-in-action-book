#!/bin/bash
if [ "$1" = 'MAINNET' ]
then
    VERSION_PREFIX_PB=80
    VERSION_PREFIX_ADDRESS=05
else
    VERSION_PREFIX_PB=EF
    VERSION_PREFIX_ADDRESS=C4
fi

for i in 1
do

  printf  "\n \e[31m ######### Create private key and public key ${i} #########\e[0m\n\n"

  #private key
  openssl ecparam -genkey -name secp256k1 -rand /dev/urandom -out private_key_$i.pem

  #private key bitcoin
  openssl ec -in private_key_$i.pem -outform DER|tail -c +8|head -c 32 |xxd -p -c 32 > btc_priv_$i.key

  #Compressed private key
  printf "\n \n 🗝 Compressed private key WIF $i \n"
  C=`printf $VERSION_PREFIX_PB$(<btc_priv_$i.key)"01" | xxd -r -p | base58 -c`
  printf $C"\n"
  printf $C > compressed_private_key_WIF_$i.txt

  #DER FORMAT
  openssl ec -in private_key_$i.pem -pubout -outform DER|tail -c 65|xxd -p -c 65 > btc_pub_$i.key

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

  printf  "\n\e[42m ######### P2SH #########\e[49m\n\n"
  PBH=$(printf $(cat compressed_public_key_1.txt | xxd -r -p | openssl sha256| sed 's/^.* //') |xxd -r -p | openssl ripemd160 | sed 's/^.* //')
  PBLENGTH=$(char2hex.sh $(printf $PBH | wc -c)) #always 14

  #$ gdate --date="@1591344300"
  #Fri Jun  5 10:05:00 CEST 2020

  #Questo funziona
  #OP_DUP OP_HASH160 <PubKHash> OP_EQUALVERIFY OP_CHECKSIG
  #512 seconds ~8.5 minutes
  # 00000000010000000000000000000001
  # convertito in base10
  # echo 'ibase=2; 00000000010000000000000000000001' | bc
  # 4194305
  #convertito in base16
  #$ echo 'obase=16; 4194305' | bc
  #400001
  # NB non aggiungiamo il padding, piu piccolo possibile perchè  OP_CHECKSEQUENCEVERIFY is a number, not a byte array
  # prefix lunghezza
  FLAG=`echo 'ibase=2; 00000000010000000000000000000001' | bc`
  FLAG_HEX=`printf $(echo 'obase=16; '$FLAG'' | bc) | tac -rs ..`
  FLAG_LENGTH=$(char2hex.sh $(printf $FLAG_HEX | wc -c))
  SCRIPT="03010040B27576a9"$PBLENGTH$PBH"88AC" #DOPO 512 secondi, 8,5 minuti

  # blocco 107
  # convertito in hex echo 'obase=16; 107' | bc
  # aggiunto padding 0000006B
  # girato l'ordine dei byte
  # prefix lunghezza
  # printf $(echo 'obase=16; 1723306' | bc) | tac -rs ..
  #SCRIPT="02C900B17576a9"$PBLENGTH$PBH"88AC"
  printf $SCRIPT > redeem_script.txt
  printf "\e[46m ---------- Redeem Script --------- \e[49m\n"
  cat redeem_script.txt

  printf "\n \n\e[46m ---------- scriptPubKey --------- \e[49m\n"
  ADDR_SHA=`printf $SCRIPT | xxd -r -p | openssl sha256| sed 's/^.* //'`
  ADDR_RIPEMD160=`printf $ADDR_SHA |xxd -r -p | openssl ripemd160 | sed 's/^.* //'`
  printf $ADDR_RIPEMD160 > scriptPubKey.txt
  cat scriptPubKey.txt

  #ADDRESS
  printf "\n \n\e[46m ---------- 🔑 ADDRESS P2SH --------- \e[49m\n"
  ADDR=`printf $VERSION_PREFIX_ADDRESS$ADDR_RIPEMD160 | xxd -p -r | base58 -c`
  echo $ADDR > address_P2SH.txt
  echo $ADDR


done
