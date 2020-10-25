#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exists. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

ADDR_MITT=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null

UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_MITT`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]' 102)
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
echo $TX_SIGNED

printf "\n\n \e[41m ######### Block height < 102. Current block height:"$(bitcoin-cli getblockchaininfo | jq -r '.blocks')". Transaction is not valid #########\e[0m\n\n"

#btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)

TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)
#echo $TXID

bitcoin-cli generatetoaddress 6 $ADDR_MITT >> /dev/null
printf "\n \e[42m ######### Block height > 102. Current block height:"$(bitcoin-cli getblockchaininfo | jq -r '.blocks')" Transaction is valid #########\e[0m\n\n"

TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)
echo $TXID
bitcoin-cli generatetoaddress 6 $ADDR_MITT >> /dev/null
