#!/bin/bash
./create_address_p2sh_p2wsh_multisignature.sh

printf "\n\e[45m######### Restarting Node #########\e[0m\n\n"

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action"
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"

#Get P2SH-P2WSH
ADDR_P2SH_P2WSH_MULTISIGNATURE=`cat address_p2sh_p2wsh_multisignature.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WSH_MULTISIGNATURE >> /dev/null

#bitcoin-cli importaddress $ADDR_P2SH_P2WSH_MULTISIGNATURE
PK1=$(cat compressed_private_key_WIF_1.txt)
PK2=$(cat compressed_private_key_WIF_2.txt)
PK3=$(cat compressed_private_key_WIF_3.txt)
CHECKSUM=$(bitcoin-cli getdescriptorinfo "sh(wsh(multi(2,$PK1,$PK2,$PK3)))" | jq -r .checksum)
bitcoin-cli importdescriptors '[{ "desc": "sh(wsh(multi(2,'$PK1','$PK2','$PK3')))#'"$CHECKSUM"'", "timestamp": "now", "internal": true }]'



#check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WSH_MULTISIGNATURE'"]' | jq
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WSH_MULTISIGNATURE'"]'`

printf  "\e[43m ######### Start with P2SH-P2WSH-MULTISIGNATURE 2-3 transaction  #########\e[0m\n\n"

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
TXIN=`bitcoin-cli getrawtransaction $TXID`


SCRIPTPUBKEY=`cat scriptPubKey.txt`
WITNESS_SCRIPT=`cat witness_script.txt`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
#TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK1'","'$PK2'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","witnessScript":"'$WITNESS_SCRIPT'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithwallet $TX_DATA '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')


printf $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED | jq

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$TXIN
fi

printf  "\n\n \e[31m ######### Send transaction #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WSH_MULTISIGNATURE
