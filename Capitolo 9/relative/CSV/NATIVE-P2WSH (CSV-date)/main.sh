#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

#create address
sh create_address_p2wsh.sh

ADDR_MITT=`cat address_P2WSH_native.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

bitcoin-cli generatetoaddress 102 $ADDR_MITT >> /dev/null

##Import address becuase it created "outside" bitcoin core. retrieve UTXO easily
bitcoin-cli importaddress $ADDR_MITT

UTXO=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]')
TXID=`echo $UTXO | jq -r '.[0].txid'`
VOUT=`echo $UTXO | jq -r '.[0].vout'`
AMOUNT_UTXO=`echo $UTXO | jq -r '.[0].amount'`
AMOUNT_TO_SPEND=`echo $UTXO | jq -r '.[0].amount-0.000009'`

bitcoin-cli getrawtransaction $TXID

TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT_TO_SPEND'}]' `
printf  "\n\e[31m ######### Transaction data #########\e[0m\n\n"
echo $TX_DATA

printf  "\n\e[33m ######### Retrieve bytes to sign (bip-0143) #########\e[0m\n\n"
# STEPS https://github.com/bitcoin/bips/blob/master/bip-0143.mediawiki#Native_P2WSH
#txin (outpoint+signature) 
#[version]      [outpoint][signature][txout]         [locktime] <-- P2PKH
#[version][flag][outpoint]  [0x00]   [txout][witness][locktime] <-- P2WPKH
# Double SHA256 of the serialization of:
#      1. nVersion of the transaction (4-byte little endian)
#      2. hashPrevouts (32-byte hash)
#      3. hashSequence (32-byte hash)
#      4. outpoint (32-byte hash + 4-byte little endian)
#      5. scriptCode of the input (serialized as scripts inside CTxOuts)
#      6. value of the output spent by this input (8-byte little endian)
#      7. nSequence of the input (4-byte little endian)
#      8. hashOutputs (32-byte hash)
#      9. nLocktime of the transaction (4-byte little endian)
#     10. sighash type of the signature (4-byte little endian

TX_VERSION=$(printf $TX_DATA | cut -c 1-8) #nVersion
echo "TX_VERSION: "$TX_VERSION

OUTPOINT=$(printf $TX_DATA | cut -c 11-82) #TX IN, VOUT
echo "OUTPOINT UTXO: "$OUTPOINT

HASH_PREV_OUT=$(printf $OUTPOINT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_PREV_OUT: "$HASH_PREV_OUT

SEC=512
BIN=$(512to2.py $SEC)
BITS=`echo 'ibase=2; 0000000001000000'$BIN | bc`
SEQUENCE=`printf $(padding.sh 8 $( echo 'obase=16; '$BITS'' | bc) | tac -rs ..)`
echo "SEQUENCE: "$SEQUENCE

HASH_SEQUENCE=$(printf $SEQUENCE | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_SEQUENCE: "$HASH_SEQUENCE

SCRIPTCODELENGTH=$(char2hex.sh $(cat witness_script.txt | wc -c))
SCRIPTCODE=$SCRIPTCODELENGTH$(cat witness_script.txt)

echo "SCRIPTCODE: "$SCRIPTCODE

#convert bitcoin unit to satoshi unit
AMOUNT_TO_SPEND=$(btc2sat.sh $AMOUNT_TO_SPEND)
echo "AMOUNT: "$AMOUNT_TO_SPEND

OUTPUT=$(printf $TX_DATA | cut -c 111-156)
echo "OUTPUT: "$OUTPUT

OUTPUT_HASH=$(printf $AMOUNT_TO_SPEND$OUTPUT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "OUTPUT_HASH: "$OUTPUT_HASH

LOCKTIME_PART=$(printf $TX_DATA | cut -c 157-164)
echo "LOCKTIME_PART: "$LOCKTIME_PART

SIGHASH=01000000
echo "SIGHASH: "$SIGHASH

#convert bitcoin unit to satoshi unit. The total UTXO amount
SIG_AMOUNT=$(btc2sat.sh $AMOUNT_UTXO)

#Frankenstein, create transaction
WITNESS_V0_DIGEST=$TX_VERSION$HASH_PREV_OUT$HASH_SEQUENCE$OUTPOINT$SCRIPTCODE$SIG_AMOUNT$SEQUENCE$OUTPUT_HASH$LOCKTIME_PART$SIGHASH
printf  "\n\e[31m ######### WITNESS_V0_DIGEST: ready to sign  #########\e[0m\n\n"
echo $WITNESS_V0_DIGEST "\n"

printf $WITNESS_V0_DIGEST | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > WITNESS_V0_DIGEST.txt

#dgst -sign/-verify only does the standard single hash, so you must either hash first and then use dgst -sign/verify or hash twice and then use pkeyutl -sign/verify.
SIGNATURE=`openssl pkeyutl -inkey private_key_1.pem -sign -in WITNESS_V0_DIGEST.txt -pkeyopt digest:sha256 | xxd -p -c 256`

#add Sighash_all
SIGNATURE="${SIGNATURE}01"
echo $SIGNATURE > signature.txt

#checking signature and fix it if necessary
sh fix_signature.sh >> /dev/null
SIGNATURE=$(cat signature.txt)

printf  "\n \e[42m ######### Create Sign Transaction #########\e[0m\n\n"

SIGNATURELENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))

TX_VERSION=$(printf $TX_DATA | cut -c 1-8) #nVersion
SEGWIT_MARKER="00"
SEGWIT_FLAG="01"
#SCRIPT_SIGLENGTH="00"
INPUT=$(printf $TX_DATA | cut -c 9-84) #number input, txid utxo, vout
FIRST_PART=$TX_VERSION$SEGWIT_MARKER$SEGWIT_FLAG$INPUT$SEQUENCE
SECOND_PART=$(printf $TX_DATA | cut -c 93-156) #number output, value, scriptPubKey

#Witness items
WITNESS_SCRIPT=$(cat witness_script.txt)
WITNESS_SCRIPT_LENGTH=$(char2hex.sh $(echo $WITNESS_SCRIPT | wc -c))
WITNESS_FIELD=$(printf "00"$SIGNATURELENGTH$SIGNATURE$WITNESS_SCRIPT_LENGTH$WITNESS_SCRIPT)
WITNESS_FIELD_COUNT="03"

#merge bytes in order to create signed transaction
TX_SIGNED=$FIRST_PART$SECOND_PART$WITNESS_FIELD_COUNT$WITNESS_FIELD$LOCKTIME_PART

printf "\n\e[32m ######### Decode sign transaction #########\e[0m\n\n"
echo $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED | jq

printf "\n \e[41m ######### ALERT #########\e[0m\n\n"
PREVIOUS_MEDIAN_TIME=$(bitcoin-cli getblock $(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.previousblockhash') | jq -r '.mediantime')
MEDIANTIME_UTXO=$(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.mediantime')
CURRENT_MEDIANTIME=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime')

echo "\n- The previous block's mediantime is: "$(tohuman.py $PREVIOUS_MEDIAN_TIME )" \n- Block UTXO's mediantime is "$(tohuman.py $MEDIANTIME_UTXO)" \n- The transaction is valid after $SEC seconds. Date:"$(tohuman.py $(forwardseconds.py $SEC $MEDIANTIME_UTXO)) " \n- bestblock's mediantime" $(tohuman.py $CURRENT_MEDIANTIME)" \n"
printf "\n \e[41m ######### Error #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

echo "\n ---------"
echo "0)🏃🏃🏻‍♂️ ARE YOU IN A HURRY? Dont wait "$(echo $SEC)" seconds."
echo "1)The difference between bestblock's mediantime and previous block's mediantime is: "$(expr $CURRENT_MEDIANTIME - $PREVIOUS_MEDIAN_TIME)" The result must be >= "$(echo $SEC)
echo '2)MOVE YOUR CLOCK @' $(tohuman.py $(forwardseconds.py $SEC)) 'or more'
echo '3)Execute => bitcoin-cli generatetoaddress 11 $(bitcoin-cli getnewaddress "" "bech32") >> /dev/null'
echo '4)Execute => bitcoin-cli sendrawtransaction '$(echo $TX_SIGNED)
echo '...OR WAIT 🤷🏻‍♂️'
echo "---------\n"

printf "\n \e[41m ######### Waiting... ⏳ #########\e[0m\n\n"
secs=$((1 * $SEC))
while [ $secs -gt 0 ]; do
   printf "$secs\n"
   sleep 1
   : $((secs--))
done

printf "\n \e[45m ######### mine 11 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 11 $ADDR_MITT

printf "\n \e[42m ######### Done! #########\e[0m\n\n"
CURRENT_MEDIANTIME=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime')
echo "The difference between bestblock's mediantime and previous block's mediantime is: "$(expr $CURRENT_MEDIANTIME - $PREVIOUS_MEDIAN_TIME)" The result must be >= "$(echo $SEC)
bitcoin-cli sendrawtransaction $TX_SIGNED

#btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
