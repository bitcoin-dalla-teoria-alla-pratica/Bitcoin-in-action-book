#!/bin/bash



bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null

printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"

#Get P2SH-P2WPKH
ADDR_P2SH_P2WPKH_NESTED=`bitcoin-cli getnewaddress "segwit sender" "p2sh-segwit"`
ADDR_DEST=`bitcoin-cli getnewaddress "legacy receiver" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WPKH_NESTED >> /dev/null
bitcoin-cli importaddress $ADDR_P2SH_P2WPKH_NESTED
#check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NESTED'"]' | jq
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NESTED'"]'`

printf  "\e[43m ######### Start with P2SH-P2WPKH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')
TXIN=`bitcoin-cli getrawtransaction $TXID`

PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH_NESTED`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

echo $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED | jq

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$TXIN
fi

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH_NESTED
