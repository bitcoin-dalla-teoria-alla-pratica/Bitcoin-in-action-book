#!/bin/bash



bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"

./create_address_p2sh_p2wsh_wrap_p2pkh.sh

#Get P2SH-P2WPKH
ADDR_P2SH_P2WSH_WRAP_P2PKH=`cat address_p2sh_p2wsh_wrap_p2pkh.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WSH_WRAP_P2PKH >> /dev/null
bitcoin-cli importaddress $ADDR_P2SH_P2WSH_WRAP_P2PKH

#check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WSH_WRAP_P2PKH'"]' | jq
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WSH_WRAP_P2PKH'"]'`

printf  "\e[43m ######### Start with P2WPKH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
TXIN=`bitcoin-cli getrawtransaction $TXID`

PK=`cat compressed_private_key_WIF_1.txt`
REDEEMSCRIPT=`cat redeem_script.txt`
SCRIPTPUBKEY=`cat scriptPubKey.txt`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","witnessScript":"'$WITNESSCRIPT'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

bitcoin-cli decoderawtransaction $TX_SIGNED | jq

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$TXIN
fi

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WSH_WRAP_P2PKH
