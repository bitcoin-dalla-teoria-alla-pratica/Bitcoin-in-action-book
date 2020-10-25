#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exists. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

ADDR_P2SH_P2WPKH_NATIVE_1=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_1=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_2=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_P2SH_P2WPKH_NATIVE_2=`bitcoin-cli addmultisigaddress 1 '["'$ADDR_1'","'$ADDR_2'"]' "" "bech32" | jq -r '.address'`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WPKH_NATIVE_1 >> /dev/null

printf "\n\n \e[107m ######### Coinbase -> P2WPKH Native -> P2WSH-P2SH (multisignature) Native  #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NATIVE_1'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH_NATIVE_1`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_NATIVE_2'":'$AMOUNT'}]')
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

bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH_NATIVE_1 >> /dev/null

printf "\n\n \e[107m ######### P2WSH-P2SH (multisignature) Native -> P2WPKH Native  #########\e[0m\n\n"
PK=`bitcoin-cli dumpprivkey $ADDR_1`
bitcoin-cli importaddress $ADDR_P2SH_P2WPKH_NATIVE_2
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2SH_P2WPKH_NATIVE_2'"]'`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].witnessScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_NATIVE_1'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"witnessScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

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
