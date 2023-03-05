#!/bin/bash
if [ "$1" = 'MAINNET' ]
then
    VERSION_PREFIX_PB=80
    HRP='bc'
else
    VERSION_PREFIX_PB=EF
    #Human readable part
    HRP='bcrt' #regtest
    #HRP='tb' #testnet
fi

CHARSET="qpzry9x8gf2tvdw0s3jn54khce6mua7l"

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

# Native P2WPKH
# Witness program: Hash160(public key)
# scriptPubKey: OP_0 <witness program>

# Public key of https://en.bitcoin.it/wiki/BIP_0173 => 0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798 => address tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx for testing (testnet)
printf "\e[46m ---------- Witness Program $i --------- \e[49m\n"
WITNESS_PROGRAM=$(printf $(cat compressed_public_key_$i.txt | xxd -r -p | openssl sha256| sed 's/^.* //') |xxd -r -p | openssl ripemd160 | sed 's/^.* //')
echo $WITNESS_PROGRAM
#https://bitcoincore.org/en/segwit_wallet_dev/ check native
#Native P2WPKH is a scriptPubKey of 22 bytes. It starts with a OP_0, followed by a canonical push of the keyhash (i.e. 0x0014{20-byte keyhash})
printf "\n\e[46m ---------- SCRIPTPUBKEY $i --------- \e[49m\n"
WITNESS_VERSION="00"
SCRIPTPUBKEY=$(printf $WITNESS_VERSION"14"$WITNESS_PROGRAM)
echo $SCRIPTPUBKEY > scriptPubKey_$i.txt
echo $SCRIPTPUBKEY

echo "ibase=16; obase=2; $(echo $WITNESS_PROGRAM  | tr '[:lower:]' '[:upper:]') " | bc  | sed 's/\\//g' | tr -d '\n' > base2.txt

printf  "\n\n \e[45m ######### Group of 8 bits #########\e[0m\n\n"
cat base2.txt | sed 's/.\{8\}/& /g' | tr -d '\n' | tr " " "\n"
#Re-arrange those bits into groups of 8 bits.
TIMES=$(expr "`cat base2.txt | wc -c`%8" | bc)
while [ $TIMES -ne 0 ]
do
  echo '0' | cat - base2.txt| tr -d '\n' | tr " " "\n" > temp && mv temp base2.txt | tr -d '\n'
  TIMES=$(expr "`cat base2.txt | wc -c`%8" | bc)
done

#Add witness version
WITNESS_VERSION=00000
echo $WITNESS_VERSION | cat - base2.txt | tr -d '\n' | tr " " "\n" > temp && mv temp base2.txt
cat base2.txt | sed 's/.\{5\}/& /g' | tr -d '\n' | tr " " "\n" > group.txt

printf  "\n\n \e[45m ######### Group of 5 bits #########\e[0m\n\n"
cat group.txt

rm -Rf base10.txt
touch base10.txt
file="group.txt"
last_line=$(wc -l < $file)
current_line=0

while IFS= read -r line
do
    echo 'ibase=2;obase=A;'$line | bc >> base10.txt
    INT=$(echo 'ibase=2;obase=A;'$line | bc)
    OFFSET=$(($INT+1))
    MAP=$MAP`printf "$CHARSET" | cut -c$OFFSET`
done < "$file"

#Remove all white spaces and add commas
BASE10=`cat base10.txt | sed '$!s/$/, /' | tr -d '\n'`
echo $BASE10

printf  "\n\n \e[45m ######### bech32 create checksum #########\e[0m\n\n"
CHECKSUM=`python3 -c "import bech32; print (bech32.bech32_create_checksum('$HRP', [$BASE10] ))"`
echo $CHECKSUM

#Extract numbers
NUMBERS=`echo $CHECKSUM | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' '`
echo $NUMBERS

for value in $NUMBERS; do  echo $value
  value=$(($value+1))
  MAP2=$MAP2`printf "$CHARSET" | cut -c$value`
done

printf  "\n\n \e[43m ######### Address P2WPKH #########\e[0m\n\n"
ADDRESS=$HRP"1"$MAP$MAP2
echo $ADDRESS > address_P2WPKH.txt
cat address_P2WPKH.txt
done
