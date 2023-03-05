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
done

# 4194305 ~8.5 minutes
# Witness script: "4194305 OP_CHECKSEQUENCEVERIFY OP_DROP 1 <pubkey> <pubkey> <pubkey> 3 OP_CHECKMULTISIG",
# Witness program: SHA256(witness script)
# scriptPubKey: OP_0 <witness program>
# ----- CREATE WITNESS SCRIPT ----
printf "\e[46m ---------- Witness Script --------- \e[49m\n"

SEC=512
BIN=$(512to2.py $SEC)
FLAG=`echo 'ibase=2; 000000001000000'$BIN | bc`
SEQUENCE_HEX=`printf $(echo 'obase=16; '$FLAG'' | bc) | tac -rs ..`
SEQUENCE_LENGTH=$(char2hex.sh $(printf $SEQUENCE_HEX | wc -c))

WITNESS_SCRIPT=$SEQUENCE_LENGTH$SEQUENCE_HEX"B2755121"$(cat compressed_public_key_1.txt)"21"$(cat compressed_public_key_2.txt)"21"$(cat compressed_public_key_3.txt)"53AE"
printf $WITNESS_SCRIPT > witness_script.txt
cat witness_script.txt

#Witness program: SHA256(witness script)
WITNESS_PROGRAM=`printf $WITNESS_SCRIPT | xxd -r -p | openssl sha256| sed 's/^.* //'`

# ----- CREATE SCRIPTPUBKEY ----
#https://bitcoincore.org/en/segwit_wallet_dev/ check native
#Native P2WSH is a scriptPubKey of 34 bytes. It starts with a OP_0, followed by a canonical push of the scripthash (i.e. 0x0020{32-byte scripthash})
printf "\n\e[46m ---------- SCRIPTPUBKEY --------- \e[49m\n"
WITNESS_VERSION="00"
#scriptPubKey: OP_0 <witness program>
SCRIPTPUBKEY=$(printf $WITNESS_VERSION"20"$WITNESS_PROGRAM)
echo $SCRIPTPUBKEY > scriptPubKey.txt
cat scriptPubKey.txt

# ----- CONVERT IN BASE2 ----
echo "ibase=16; obase=2; $(echo $WITNESS_PROGRAM  | tr '[:lower:]' '[:upper:]') " | bc  | sed 's/\\//g' | tr -d '\n' > base2.txt

printf  "\n\n \e[45m ######### Group of 8 bits #########\e[0m\n\n"
#Re-arrange those bits into groups of 8 bits.
TIMES=$(expr "`cat base2.txt | wc -c`%8" | bc)
while [ $TIMES -ne 0 ]
do
  echo '0' | cat - base2.txt| tr -d '\n' | tr " " "\n" > temp && mv temp base2.txt | tr -d '\n'
  TIMES=$(expr "`cat base2.txt | wc -c`%8" | bc)
done

cat base2.txt | sed 's/.\{8\}/& /g' | tr -d '\n' | tr " " "\n"

WITNESS_VERSION=00000
echo $WITNESS_VERSION | cat - base2.txt | tr -d '\n' | tr " " "\n" > temp && mv temp base2.txt

cat base2.txt | sed 's/.\{8\}/& /g' | tr -d '\n' | tr " " "\n" > group.txt
cat group.txt

printf  "\n\n \e[45m ######### Group of 5 bits #########\e[0m\n\n"
#Re-arrange those bits into groups of 5 bits.
TIMES=$(expr "`cat group.txt | wc -c`%5" | bc)
while [ $TIMES -ne 0 ]
do
  echo '0' >> group.txt
  cat group.txt| tr -d '\n' | tr " " "\n" > temp && mv temp group.txt | tr -d '\n'
  TIMES=$(expr "`cat group.txt | wc -c`%5" | bc)
done

cat group.txt | sed 's/.\{5\}/& /g' | tr -d '\n' | tr " " "\n" > group_to_five.txt
cat group_to_five.txt

# ----- read each line and convert in base10 ----
file="group_to_five.txt"
last_line=$(wc -l < $file)
current_line=0
#convert from BASE2 to BASE10
MAP=''
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

# ----- GET CHECKSUM ----
CHECKSUM=`python3 -c "import bech32; print (bech32.bech32_create_checksum('$HRP', [$BASE10] ))"`
printf "\n Checksum \n"
echo $CHECKSUM

#Extract numbers
NUMBERS=`echo $CHECKSUM | tr '\n' ' ' | sed -e 's/[^0-9]/ /g' -e 's/^ *//g' -e 's/ *$//g' | tr -s ' '`
printf "\n Number \n"
echo $NUMBERS

#Map with Charset
MAP2=''
for value in $NUMBERS; do echo $value
  value=$(($value+1))
  MAP2=$MAP2`printf "$CHARSET" | cut -c$value`
done

printf  "\n\n \e[43m ######### Address P2WSH - Native $i #########\e[0m\n\n"
ADDRESS=$HRP"1"$MAP$MAP2
echo $ADDRESS > address_P2WSH_native.txt
cat address_P2WSH_native.txt

# tester http://bitcoin.sipa.be/bech32/demo/demo.html
rm base2.txt
rm base10.txt
rm group_to_five.txt
rm group.txt
