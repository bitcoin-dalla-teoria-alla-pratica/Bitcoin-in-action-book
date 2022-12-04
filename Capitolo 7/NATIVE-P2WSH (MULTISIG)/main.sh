#!/bin/bash


./create_address_p2wsh_multisig.sh

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_P2WSH_MULTISIG=`cat address_P2WSH_native_multisig.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2WSH_MULTISIG >> /dev/null
bitcoin-cli importaddress $ADDR_P2WSH_MULTISIG

check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2WSH_MULTISIG'"]' | jq

UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2WSH_MULTISIG'"]'`

printf  "\e[43m ######### Start with P2WSH (multisignature) transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
TXIN=`bitcoin-cli getrawtransaction $TXID`

PK1=`cat compressed_private_key_WIF_1.txt`
PK2=`cat compressed_private_key_WIF_2.txt`

SCRIPTPUBKEY=`cat scriptPubKey.txt`
WITNESS_SCRIPT=$(cat witness_script.txt)

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK1'","'$PK2'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"witnessScript":"'$WITNESS_SCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$TXIN
fi

bitcoin-cli decoderawtransaction $TX_SIGNED | jq

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2WSH_MULTISIG
