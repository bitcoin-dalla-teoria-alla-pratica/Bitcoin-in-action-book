#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

ADDR_P2SH_P2WPKH=`bitcoin-cli getnewaddress "" "p2sh-segwit"`
ADDR_P2PKH=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WPKH >> /dev/null

printf "\n\n \e[104m ######### Coinbase -> P2SH-P2WSH -> P2PKH  #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2PKH'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

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

bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH >> /dev/null

printf "\n\n \e[104m ######### P2PKH -> P2SH-P2WSH  #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2PKH'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH'":'$AMOUNT'}]')
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
