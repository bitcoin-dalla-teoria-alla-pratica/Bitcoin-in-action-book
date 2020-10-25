#!/bin/sh
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

  #DER format
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


  # Witness program: Hash160(public key)
  # redeemScript: OP_0 <witness program>
  # Script hash: Hash160(redeemScript)
  # scriptPubKey: OP_HASH160 <script hash> OP_EQUAL

  printf  "\n\e[42m ######### P2SH-P2WPKH $i #########\e[49m\n\n"
  # https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#p2wpkh-nested-in-bip16-p2sh
  WITNESS_PROGRAM=$(printf $(cat compressed_public_key_$i.txt | xxd -r -p | openssl sha256| sed 's/^.* //') |xxd -r -p | openssl ripemd160 | sed 's/^.* //')

  printf "\e[46m ---------- Redeem Script $i --------- \e[49m\n"
  # redeem script
  # Witness version + witness program
  # 0 <20-byte-PublicKeyHash>
  WITNESS_VERSION="00"
  REDEEM_SCRIPT=$WITNESS_VERSION"14"$WITNESS_PROGRAM
  printf $REDEEM_SCRIPT > redeem_script_$i.txt
  cat redeem_script_$i.txt

  #scriptPubKey
  #OP_HASH160 <20-byte-redeemScriptHash> OP_EQUAL
  #(0xA914{20-byte-script-hash}87)
  printf "\n \n\e[46m ---------- scriptPubKey $i--------- \e[49m\n"
  SCRIPTHASH=$(printf $(cat redeem_script_$i.txt | xxd -r -p | openssl sha256| sed 's/^.* //') |xxd -r -p | openssl ripemd160 | sed 's/^.* //')
  SCRIPTPUBKEY="a914"$SCRIPTHASH"87"
  printf $SCRIPTPUBKEY > scriptPubKey_$i.txt
  cat scriptPubKey_$i.txt

  #ADDRESS
  printf "\n \n\e[46m ---------- 🔑 ADDRESS P2SH-P2WPKH $i--------- \e[49m\n"
  ADDR=`printf $VERSION_PREFIX_ADDRESS$SCRIPTHASH | xxd -p -r | base58 -c`
  echo $ADDR > address_P2SH_P2WPKH_$i.txt
  echo $ADDR

done
