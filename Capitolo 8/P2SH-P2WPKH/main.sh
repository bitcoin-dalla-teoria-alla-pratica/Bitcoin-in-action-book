#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" 
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"

#Get P2SH-P2WPKH
./create_p2sh_address_p2wpkh.sh
ADDR_MITT=`cat address_P2SH_P2WPKH_1.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "segwit receiver" "p2sh-segwit"`

bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null


PK=$(cat compressed_private_key_WIF_1.txt)
CHECKSUM=$(bitcoin-cli getdescriptorinfo "sh(wpkh($PK))" | jq -r .checksum)
bitcoin-cli importdescriptors '[{ "desc": "sh(wpkh('$PK'))#'"$CHECKSUM"'", "timestamp": "now", "internal": true }]'


#check amount
printf  "\n\n \e[45m ######### Check UTXO #########\e[0m\n\n"
bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq

UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]'`

printf  "\e[43m ######### Start with P2SH-P2WPKH  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT_UTXO=`echo $UTXO | jq -r '.[0].amount'`
AMOUNT_TO_SPEND=`echo $UTXO | jq -r '.[0].amount-0.000009'`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT_TO_SPEND'}]')
printf  "\n\e[31m ######### Transaction data #########\e[0m\n\n"
echo $TX_DATA

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

SEQUENCE=$(printf $TX_DATA | cut -c 85-92)
echo "SEQUENCE: "$SEQUENCE

HASH_PREV_OUT=$(printf $OUTPOINT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_PREV_OUT: "$HASH_PREV_OUT

HASH_SEQUENCE=$(printf $SEQUENCE | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "HASH_SEQUENCE: "$HASH_SEQUENCE

PB=$(printf $(cat compressed_public_key_1.txt | xxd -r -p | openssl sha256| sed 's/^.* //') |xxd -r -p | openssl ripemd160 | sed 's/^.* //')
PBLENGTH=$(char2hex.sh $(printf $PB | wc -c))
#OP_DUP OP_HASH160 <Public KeyHash> OP_EQUAL OP_CHECKSIG
SCRIPTCODE="1976a9"$PBLENGTH$PB"88AC"
echo "SCRIPTCODE: "$SCRIPTCODE

#convert bitcoin unit to satoshi unit
AMOUNT_TO_SPEND=$(btc2sat.sh $AMOUNT_TO_SPEND)
echo "AMOUNT: "$AMOUNT_TO_SPEND

OUTPUT=$(printf $TX_DATA | cut -c 111-158) #P2SH-P2WPKH receiver OP_HASH160 <redeem script hash> <OP_EQUAL>
echo "OUTPUT: "$OUTPUT

OUTPUT_HASH=$(printf $AMOUNT_TO_SPEND$OUTPUT | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
echo "OUTPUT_HASH: "$OUTPUT_HASH
LOCKTIME_PART=$(printf $TX_DATA | cut -c 159-166)
echo "LOCKTIME_PART: "$LOCKTIME_PART
SIGHASH=01000000
echo "SIGHASH: "$SIGHASH

#convert bitcoin unit to satoshi unit. The total UTXO amount
SIG_AMOUNT=$(btc2sat.sh $AMOUNT_UTXO) #7CEE052A01000000 50 bitcoin

#Frankenstein, create transaction
WITNESS_V0_DIGEST=$TX_VERSION$HASH_PREV_OUT$HASH_SEQUENCE$OUTPOINT$SCRIPTCODE$SIG_AMOUNT$SEQUENCE$OUTPUT_HASH$LOCKTIME_PART$SIGHASH
echo $WITNESS_V0_DIGEST
printf  "\n\e[31m ######### WITNESS_V0_DIGEST: ready to sign  #########\e[0m\n\n"

printf $WITNESS_V0_DIGEST | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > WITNESS_V0_DIGEST.txt
echo $WITNESS_V0_DIGEST
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

#Get Public key
PB=`cat compressed_public_key_1.txt`
PBLENGTH=$(char2hex.sh $(echo $PB | wc -c))

SEGWIT_MARKER="00"
SEGWIT_FLAG="01"
REDEEM_SCRIPT=$(cat redeem_script_1.txt)
REDEEM_SCRIPT_LENGTH=$(char2hex.sh $(echo $REDEEM_SCRIPT | wc -c))
SCRIPT_SIGLENGTH=$(char2hex.sh $(echo $REDEEM_SCRIPT_LENGTH$REDEEM_SCRIPT | wc -c))

INPUT=$(printf $TX_DATA | cut -c 9-82) #number input, txid utxo, vout
FIRST_PART=$TX_VERSION$SEGWIT_MARKER$SEGWIT_FLAG$INPUT$SCRIPT_SIGLENGTH$REDEEM_SCRIPT_LENGTH$REDEEM_SCRIPT
SECOND_PART=$(printf $TX_DATA | cut -c 85-158) #nsequence,number output, value, scriptPubKey

#Witness items
WITNESS_FIELD_COUNT="02"
WITNESS_FIELD=$(printf $SIGNATURELENGTH$SIGNATURE$PBLENGTH$PB)


#merge bytes in order to create signed transaction
TX_DATA_SIGNED=$FIRST_PART$SECOND_PART$WITNESS_FIELD_COUNT$WITNESS_FIELD$LOCKTIME_PART

printf "\n\e[32m ######### Decode sign transaction #########\e[0m\n\n"
echo $TX_DATA_SIGNED
bitcoin-cli decoderawtransaction $TX_DATA_SIGNED | jq

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf  "\n\e[32m ######### Send Transaction #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

printf "\n\n \e[105m ######### mine blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
