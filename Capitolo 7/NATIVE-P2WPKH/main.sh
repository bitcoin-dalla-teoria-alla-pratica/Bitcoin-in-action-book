#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exists. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

sh create_address_p2wpkh.sh

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_P2WPKH=`cat address_P2WPKH.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2WPKH >> /dev/null
bitcoin-cli importaddress $ADDR_P2WPKH

#check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2WPKH'"]' | jq
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2WPKH'"]'`

printf  "\e[43m ######### Start with P2WPKH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
TXIN=`bitcoin-cli getrawtransaction $TXID`

PK=`cat compressed_private_key_WIF_1.txt`
SCRIPTPUBKEY=`cat scriptPubKey_1.txt`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

bitcoin-cli decoderawtransaction $TX_SIGNED | jq

#btcdeb --tx=$TX_SIGNED --txin=$TXIN

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2WPKH
