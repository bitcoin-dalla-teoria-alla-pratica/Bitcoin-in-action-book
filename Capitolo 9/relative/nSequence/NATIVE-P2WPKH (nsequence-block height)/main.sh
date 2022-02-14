#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5
bitcoin-cli createwallet "bitcoin in action" >> /dev/null

ADDR_MITT=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

bitcoin-cli generatetoaddress 144  $(bitcoin-cli getnewaddress "" "bech32") >> /dev/null
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null

UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_MITT`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

SEQUENCE_HEIGHT=1618

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT',"sequence":'$SEQUENCE_HEIGHT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

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
bitcoin-cli decoderawtransaction $TX_SIGNED | jq
