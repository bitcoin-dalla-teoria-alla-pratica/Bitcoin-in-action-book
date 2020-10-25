#!/bin/sh
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

  #DER Format
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
done

  # Witness script: OP_1 <Public Key hash> <Public Key hash> <Public Key hash> 3 OP_CHECKMULTISIG
  # Witness program: SHA256(witness script)
  # redeemScript: OP_0 <witness program>
  # Script hash: Hash160(redeemScript)
  # scriptPubKey: OP_HASH160 <script hash> OP_EQUAL
  printf  "\n\e[42m ######### P2SH-P2WSH-WRAP(MULTISIG 1-3) #########\e[49m\n\n"

  #OP_1 <Public Key hash> <Public Key hash> <Public Key hash> 3 OP_CHECKMULTISIG
  WITNESS_SCRIPT="5121"$(cat compressed_public_key_1.txt)"21"$(cat compressed_public_key_2.txt)"21"$(cat compressed_public_key_3.txt)"53AE"
  printf $WITNESS_SCRIPT > witness_script.txt
  printf "\e[46m ---------- Witness Script --------- \e[49m\n"
  cat witness_script.txt

  WITNESS_PROGRAM=`printf $WITNESS_SCRIPT | xxd -r -p | openssl sha256| sed 's/^.* //'`

  printf "\n \e[46m ---------- REDEEM_SCRIPT (Witness version - Witness program)--------- \e[49m\n"
  WITNESS_VERSION="00"
  REDEEM_SCRIPT=$WITNESS_VERSION"20"$WITNESS_PROGRAM
  printf $REDEEM_SCRIPT
  printf $REDEEM_SCRIPT > redeem_script.txt

  printf "\n \e[46m ---------- SCRIPTPUBKEY --------- \e[49m\n"
  #OP_HASH160 hash160(redeemScript) OP_EQUAL
  SCRIPT_HASH=$(printf $(printf $REDEEM_SCRIPT | xxd -r -p | openssl sha256| sed 's/^.* //') | xxd -r -p | openssl ripemd160 | sed 's/^.* //')
  SCRIPTPUBKEY="A914"$SCRIPT_HASH"87"
  printf $SCRIPTPUBKEY > scriptPubKey.txt
  printf $SCRIPTPUBKEY

  #ADDRESS
  printf "\n\e[46m ---------- 🔑 ADDRESS P2SH-P2WSH Multisignature --------- \e[49m\n"
  ADDR=`printf $VERSION_PREFIX_ADDRESS$SCRIPT_HASH | xxd -p -r | base58 -c`
  printf $ADDR > address_p2sh_p2wsh_multisig.txt
  printf $ADDR
