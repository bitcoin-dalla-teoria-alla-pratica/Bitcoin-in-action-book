#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5

#create address
./create_address_p2wsh.sh

bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null
printf  "\n\n \e[45m ######### Mine 101 blocks and get reward#########\e[0m"

ADDR_MITT=`cat address_P2WSH_native.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

#mint blocks
bitcoin-cli generatetoaddress 144  $(bitcoin-cli getnewaddress "" "bech32") >> /dev/null
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

SEQUENCE_HEIGHT=1618
BIN=$(echo 'obase=2; '$SEQUENCE_HEIGHT'' | bc)
BITS="0000000000000000"$BIN
SEQUENCE=$(printf $(padding.sh 8 $(echo 'obase=16; '$SEQUENCE_HEIGHT | bc)) | tac -rs ..)
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

#TIME=$(gdate --date 'now + 20 seconds' +%s)
#LOCKTIME_PART=$(printf $(echo 'obase=16; '$TIME' ' | bc) | tac -rs ..)
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
./fix_signature.sh >> /dev/null
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


PREVIOUS_HEIGHT=$(bitcoin-cli getblock $(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.previousblockhash') | jq -r '.height')
BEST_BLOCK_HEIGHT=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.height')
TIP_MIN_HEIGHT=$(expr $PREVIOUS_HEIGHT + $SEQUENCE_HEIGHT)
DIFF=$(expr $TIP_MIN_HEIGHT - $BEST_BLOCK_HEIGHT)

printf "\e[41m ######### The transaction is invalid until $SEQUENCE_HEIGHT blocks have elapsed since input's prevout confirms. The Previous block height is:$PREVIOUS_HEIGHT #########\e[0m\n\n"
printf "\e[41m ######### The block tip must have $TIP_MIN_HEIGHT height. Now is $BEST_BLOCK_HEIGHT. You must mine blocks $DIFF #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED
bitcoin-cli generatetoaddress $DIFF $ADDR_MITT >> /dev/null

BEST_BLOCK_HEIGHT=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.height')
printf "\e[42m ######### The Best block height is: $BEST_BLOCK_HEIGHT. the transaction is valid! 💪🏻 #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi


bitcoin-cli decoderawtransaction $TX_SIGNED | jq
