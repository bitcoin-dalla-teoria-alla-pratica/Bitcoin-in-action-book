#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exists. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

#create address
sh create_address_p2wsh.sh

printf  "\n\n \e[45m ######### Mine 101 blocks and get reward#########\e[0m"

ADDR_MITT=`cat address_P2WSH_native.txt`
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
AMOUNT_TO_SPEND=`echo $UTXO | jq -r '.[0].amount-0.000009'`

bitcoin-cli getrawtransaction $TXID

TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT_TO_SPEND'}]' `
printf  "\n\e[31m ######### Transaction data #########\e[0m\n\n"
echo $TX_DATA

TX_VERSION=$(printf $TX_DATA | cut -c 1-8)
LOCKTIME_PART=$(printf $TX_DATA | cut -c 157-164)
SEGWIT_MARKER="00"
SEGWIT_FLAG="01"
TX_DATA=$TX_VERSION$SEGWIT_MARKER$SEGWIT_FLAG$(echo "${TX_DATA:8:148}")

#HEX
HEX=$(printf "nakamoto" | xxd -ps)
HEXLENGTH=$(char2hex.sh $(echo $HEX | wc -c))


#Witness items
WITNESS_SCRIPT=$(cat witness_script.txt)
WITNESS_SCRIPT_LENGTH=$(char2hex.sh $(echo $WITNESS_SCRIPT | wc -c))

# Password satoshi
# Insert 0101 after #HEX
# The flow needs to check the first condition

# Password nakamoto
# Insert 00 after #HEX
# The flow needs to check the ELSE condition

WITNESS_FIELD=$(printf $HEXLENGTH$HEX"00"$WITNESS_SCRIPT_LENGTH$WITNESS_SCRIPT)
WITNESS_FIELD_COUNT="03"

#merge bytes in order to create signed transaction
TX_DATA_SIGNED=$TX_DATA$WITNESS_FIELD_COUNT$WITNESS_FIELD$LOCKTIME_PART

printf "\n\e[32m ######### Decode sign transaction #########\e[0m\n\n"
echo $TX_DATA_SIGNED
bitcoin-cli decoderawtransaction $TX_DATA_SIGNED | jq

#btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)

printf  "\n\e[32m ######### Send Transaction #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

printf "\n\n \e[105m ######### mine blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
