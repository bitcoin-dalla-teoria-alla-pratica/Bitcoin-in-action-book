#!/bin/bash

sh main.sh
TX_DATA=$(cat transaction_data.txt)
echo $TX_DATA
echo "\n"
#bitcoin-cli decoderawtransaction $TX_DATA | jq

#Transaction version
printf "\e[33m Version: `printf $TX_DATA | cut -c 1-8` \n \e[31m"

#How many inputs
NUM_INPUT=$(echo "ibase=16;`printf $TX_DATA | cut -c 9-10`" | bc)
printf "\e[34m #inputs: $NUM_INPUT \n \e[34m"

INIT=11

printf "\n \e[46m ---------- INPUT --------- \e[49m \n "
C=1

while [[ $C -le $NUM_INPUT ]]
do

TXID_LENGTH=$(expr `echo $INIT+63 | bc`)
TXID_UTXO=$(printf `printf $TX_DATA | cut -c $INIT-$TXID_LENGTH` | tac -rs ..)
printf "\n TXID UTXO (32 byte):$TXID_UTXO \n \e[31m"

TXID_LENGTH=$(expr `echo $TXID_LENGTH+1 | bc`)
VOUT_LENGTH=$(expr `echo $TXID_LENGTH+7 | bc`)
VOUT=$(printf $TX_DATA | cut -c $TXID_LENGTH-$VOUT_LENGTH)
printf "\n vout, UTXO index (4 byte): $VOUT \n \e[36m"


VOUT_INDEX=`echo "ibase=16; $VOUT" | bc`
UTXO_TYPE=$(bitcoin-cli getrawtransaction $TXID_UTXO 2 | jq -r '.vout['$VOUT_INDEX'].scriptPubKey.type')

printf "\n Type script: $UTXO_TYPE \e[92m \n"

if [ $UTXO_TYPE = 'pubkeyhash' ]
then

    VOUT_LENGTH=$(expr `echo $VOUT_LENGTH+1 | bc`)
    SCRIPTLENGTH=$(expr `echo $VOUT_LENGTH+1 | bc`)
    SCRIPT_LENGTH_HEX=`printf $TX_DATA | cut -c $VOUT_LENGTH-$SCRIPTLENGTH`
    SCRIPT_LENGTH_CHAR=$(hex2char.sh $SCRIPT_LENGTH_HEX)
    printf "\n scriptSig length: HEX:$SCRIPT_LENGTH_HEX - how many char :$SCRIPT_LENGTH_CHAR \n \e[92m"

    SCRIPTLENGTH=$(expr `echo $SCRIPTLENGTH+1 | bc`)
    SCRIPTSIG=$(expr `echo $SCRIPTLENGTH+$SCRIPT_LENGTH_CHAR-1 | bc`)

    printf "\n scriptSig: `printf $TX_DATA | cut -c $SCRIPTLENGTH-$SCRIPTSIG` \n \e[92m"

    SIGNATURE=$(expr `echo $SCRIPTLENGTH+1 | bc`)
    SIGNATURE_LENGTH_HEX=`printf $TX_DATA | cut -c $SCRIPTLENGTH-$SIGNATURE`

    SIGNATURE_LENGTH_CHAR=$(hex2char.sh $SIGNATURE_LENGTH_HEX)
    printf "\n \t scriptSig signature length: HEX:$SIGNATURE_LENGTH_HEX - how many char:$SIGNATURE_LENGTH_CHAR \n \e[92m"

    SIGNATURE_START=$(expr `echo $SIGNATURE+1 | bc`)
    SIGNATURE_END=$(expr `echo $SIGNATURE+$SIGNATURE_LENGTH_CHAR | bc`)
    printf "\n \t Signature: `printf $TX_DATA | cut -c $SIGNATURE_START-$SIGNATURE_END` \n \e[92m"

    PB_LENGTH_START=$(expr `echo $SIGNATURE_END+1 | bc`)
    PB_LENGTH_END=$(expr `echo $PB_LENGTH_START+1 | bc`)
    PB_LENGTH_LENGTH_HEX=`printf $TX_DATA | cut -c $PB_LENGTH_START-$PB_LENGTH_END`

    PB_LENGTH_LENGTH_CHAR=$(hex2char.sh $PB_LENGTH_LENGTH_HEX)
    printf "\n \t scriptSig Public length: HEX:$PB_LENGTH_LENGTH_HEX - how many char:$PB_LENGTH_LENGTH_CHAR \n \e[33m"

    PB_START=$(expr `echo $PB_LENGTH_END+1 | bc`)
    PB_END=$(expr `echo $PB_LENGTH_END+$PB_LENGTH_LENGTH_CHAR | bc`)

    printf "\n \t Public Key: `printf $TX_DATA | cut -c $PB_START-$PB_END` \n \e[95m"

    PB_END=$(expr `echo $PB_END+1 | bc`)
    SEQUENCE=$(expr `echo $PB_END+7 | bc`)
    printf "\n Sequence: `printf $TX_DATA | cut -c $PB_END-$SEQUENCE` \n \e[34m"

    SEQUENCE=$(expr `echo $SEQUENCE+1 | bc`)
    INIT=$SEQUENCE
    fi

C=$((C+1))
printf "\n --------"
done

printf "\n \e[42m ---------- OUTPUT --------- \e[49m \n "

#check how many output
NUM_OUTPUT_LENGTH=$(expr `echo $SEQUENCE+1 | bc`)
NUM_OUTPUT=$(echo "ibase=16;`printf $TX_DATA | cut -c $SEQUENCE-$NUM_OUTPUT_LENGTH`" | bc)

INDEX=0
for (( c=1; c<=$NUM_OUTPUT; c++ ))
do

UTXO_TYPE=$(bitcoin-cli decoderawtransaction $TX_DATA | jq -r '.vout['$INDEX'].scriptPubKey.type')

printf "\n New UTXO created: $(bitcoin-cli decoderawtransaction $TX_DATA | jq -r '.vout['$INDEX'].scriptPubKey.type') \e[92m \n"

    if [ $UTXO_TYPE = 'pubkeyhash' ] || [ "$UTXO_TYPE" = "nulldata" ]
    then
        #value 8 bytes
        NUM_OUTPUT_LENGTH=$(expr `echo $NUM_OUTPUT_LENGTH+1 | bc`)
        VALUE_LENGTH=$(expr `echo $NUM_OUTPUT_LENGTH+15 | bc`)
        VALUE_SATOSHI=`printf $TX_DATA | cut -c $NUM_OUTPUT_LENGTH-$VALUE_LENGTH`
        #VALUE_BTC=`echo "$(echo "ibase=16; $(echo $(printf $VALUE_SATOSHI | tac -rs ..) | tr '[:lower:]' '[:upper:]') " | bc)*10^-08" | bc -l`
        VALUE_BTC=$(sat2btc.sh $VALUE_SATOSHI)
        printf "\n Value (8 byte, 16 char hex) in satoshi unit is: $VALUE_SATOSHI - in bitcoin unit is :$VALUE_BTC \n \e[33m"

        #ScriptPubKey length
        VALUE_LENGTH=$(expr `echo $VALUE_LENGTH+1 | bc`)
        SCRIPTPUBKEY_LENGTH=$(expr `echo $VALUE_LENGTH+1 | bc`)

        SCRIPTPUBKEY_LENGTH_HEX=`printf $TX_DATA | cut -c $VALUE_LENGTH-$SCRIPTPUBKEY_LENGTH`
        SCRIPTPUBKEY_LENGTH_CHAR=$(hex2char.sh $SCRIPTPUBKEY_LENGTH_HEX)
        printf "\n scriptPubKey length: HEX:$SCRIPTPUBKEY_LENGTH_HEX - how many char:$SCRIPTPUBKEY_LENGTH_CHAR \n \e[33m"

        #ScriptPubKey
        SCRIPTPUBKEY_LENGTH=$(expr `echo $SCRIPTPUBKEY_LENGTH+1 | bc`)
        SCRIPTPUBKEY=$(expr `echo $SCRIPTPUBKEY_LENGTH+$SCRIPTPUBKEY_LENGTH_CHAR-1 | bc`)
        printf "\n ScriptPubKey: `printf $TX_DATA | cut -c $SCRIPTPUBKEY_LENGTH-$SCRIPTPUBKEY` \e[34m"
        printf "\n ScriptPubKey: `bitcoin-cli decoderawtransaction $TX_DATA | jq -r '.vout['$INDEX'].scriptPubKey.asm'` \n \e[34m"

        NUM_OUTPUT_LENGTH=$SCRIPTPUBKEY

    fi
        INDEX=$((INDEX + 1))
        printf "\n --------"
done

#locktime 4 bytes
SCRIPTPUBKEY=$(expr `echo $SCRIPTPUBKEY+1 | bc`)
LOCKTIME_LENGTH=$(expr `echo $SCRIPTPUBKEY+7 | bc`)

printf "\n \e[42m ------------------- \e[49m \n "
printf "\n Locktime: `printf $TX_DATA | cut -c $SCRIPTPUBKEY-$LOCKTIME_LENGTH` \n \e[95m"
