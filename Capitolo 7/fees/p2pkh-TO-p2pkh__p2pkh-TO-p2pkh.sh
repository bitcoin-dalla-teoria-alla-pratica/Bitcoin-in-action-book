#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

ADDR_P2PKH=`bitcoin-cli getnewaddress "" "legacy"`
ADDR_P2PKH_2=`bitcoin-cli getnewaddress '' 'legacy'`

bitcoin-cli generatetoaddress 101 $ADDR_P2PKH >> /dev/null

printf "\n\n \e[107m ######### Coinbase -> P2PKH -> P2PKH  #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2PKH'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2PKH_2'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]'| jq -r '.hex')

TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "txid: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.txid')
echo "\n"
printf "hash: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
echo "\n"
printf "size: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.size')
echo "\n"
printf "vsize: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vsize')
echo "\n"
printf "weight: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.weight')
echo "\n"
expr "byte: "$(expr `printf $TX_SIGNED | wc -c` / 2)

bitcoin-cli generatetoaddress 6 $ADDR_P2PKH >> /dev/null

printf "\n\n \e[107m ######### P2PKH -> P2PKH  #########\e[0m\n\n"
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH_2`
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2PKH_2'"]'`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2PKH_2'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')

TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "txid: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.txid')
echo "\n"
printf "hash: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
echo "\n"
printf "size: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.size')
echo "\n"
printf "vsize: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vsize')
echo "\n"
printf "weight: "$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.weight')
echo "\n"
expr "byte: "$(expr `printf $TX_SIGNED | wc -c` / 2)
