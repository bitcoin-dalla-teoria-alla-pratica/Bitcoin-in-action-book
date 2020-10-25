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

printf  "\n\n \e[45m ######### Mine 101 blocks and get reward#########\e[0m"

ADDR_MITT=`cat address_P2WSH_native_1.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

#mint blocks
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
#to retrieve UTXO easily
bitcoin-cli importaddress $ADDR_MITT

#check amount
printf  "\n\n \e[32m ######### UTXO #########\e[0m\n\n"
bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq
UTXO=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]')
TXID=`echo $UTXO | jq -r '.[0].txid'`
VOUT=`echo $UTXO | jq -r '.[0].vout'`
AMOUNT_UTXO=`echo $UTXO | jq -r '.[0].amount'`
AMOUNT_TO_SPEND=`echo $UTXO | jq -r '.[0].amount-0.000009'`

bitcoin-cli getrawtransaction $TXID
#bitcoin-cli getrawtransaction $TXID 2 | jq

TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT_TO_SPEND'}]'`
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

#SEQUENCE=$(printf $TX_DATA | cut -c 85-92)
#must be lower than FFFFFFFF
SEQUENCE=FFFFFFFE
echo "SEQUENCE: "$SEQUENCE

HASH_PREV_OUT=$(printf $OUTPOINT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_PREV_OUT: "$HASH_PREV_OUT

HASH_SEQUENCE=$(printf $SEQUENCE | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_SEQUENCE: "$HASH_SEQUENCE

SCRIPTCODELENGTH=$(char2hex.sh $(cat witness_script_1.txt | wc -c))
SCRIPTCODE=$SCRIPTCODELENGTH$(cat witness_script_1.txt)

echo "SCRIPTCODE: "$SCRIPTCODE

#convert bitcoin unit to satoshi unit
AMOUNT_TO_SPEND=$(btc2sat.sh $AMOUNT_TO_SPEND)
echo "AMOUNT: "$AMOUNT_TO_SPEND

OUTPUT=$(printf $TX_DATA | cut -c 111-156)
echo "OUTPUT: "$OUTPUT

OUTPUT_HASH=$(printf $AMOUNT_TO_SPEND$OUTPUT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "OUTPUT_HASH: "$OUTPUT_HASH

#how many block? base10
BLOCKHEIGHT=102
LOCKTIME_PART=$(sh padding.sh 8 $(printf $(echo 'obase=16; '$BLOCKHEIGHT' ' | bc)) | tac -rs ..)
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

#Get Public key
PB=`cat compressed_public_key_1.txt`
PBLENGTH=$(char2hex.sh $(echo $PB | wc -c))

SEGWIT_MARKER="00"
SEGWIT_FLAG="01"
SCRIPT_SIGLENGTH="00"
INPUT=$(printf $TX_DATA | cut -c 9-82) #number input, txid utxo, vout
FIRST_PART=$TX_VERSION$SEGWIT_MARKER$SEGWIT_FLAG$INPUT$SCRIPT_SIGLENGTH
SECOND_PART=$(printf $TX_DATA | cut -c 93-156) #nsequence,number output, value, scriptPubKey

#Witness items
WITNESS_SCRIPT=$(cat witness_script_1.txt)
WITNESS_SCRIPT_LENGTH=$(char2hex.sh $(echo $WITNESS_SCRIPT | wc -c))
WITNESS_FIELD=$(printf $SIGNATURELENGTH$SIGNATURE$PBLENGTH$PB$WITNESS_SCRIPT_LENGTH$WITNESS_SCRIPT)
WITNESS_FIELD_COUNT="03"

#merge bytes in order to create signed transaction
TX_SIGNED=$FIRST_PART$SEQUENCE$SECOND_PART$WITNESS_FIELD_COUNT$WITNESS_FIELD$LOCKTIME_PART

printf "\n \e[41m ######### ALERT #########\e[0m\n\n"
printf "\n\n \e[41m ######### Block height <  "$BLOCKHEIGHT". Current block height:"$(bitcoin-cli getblockchaininfo | jq -r '.blocks')". Transaction is not valid #########\e[0m\n\n"

bitcoin-cli sendrawtransaction $TX_SIGNED

bitcoin-cli generatetoaddress 6 $ADDR_MITT >> /dev/null
printf "\n \e[42m ######### Block height > "$BLOCKHEIGHT". Current block height:"$(bitcoin-cli getblockchaininfo | jq -r '.blocks')" Transaction is valid #########\e[0m\n\n"
echo $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED | jq

bitcoin-cli sendrawtransaction $TX_SIGNED
