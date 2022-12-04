#!/bin/bash



bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"

#Get P2SH-P2WPKH
ADDR_P2SH_P2WPKH_NATIVE=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_P2SH_P2WPKH_2=`bitcoin-cli getnewaddress "" "p2sh-segwit"`
ADDR_P2SH_P2WPKH_3=`bitcoin-cli getnewaddress "" "p2sh-segwit"`
ADDR_P2PKH=`bitcoin-cli getnewaddress "" "legacy"`
ADDR_P2PKH_2=`bitcoin-cli getnewaddress "" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WPKH_NATIVE >> /dev/null
#check amount
bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NATIVE'"]' | jq
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NATIVE'"]'`

printf  "\e[43m ######### Start with P2SH-P2WPKH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
# AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')
TXIN=`bitcoin-cli getrawtransaction $TXID`

PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH_NATIVE`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_2'":12.5},{"'$ADDR_P2SH_P2WPKH_3'":12.5},{"'$ADDR_P2PKH'":12.5},{"'$ADDR_P2PKH_2'":6.4998},{"'$ADDR_P2SH_P2WPKH_NATIVE'":6}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

echo $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED | jq

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$TXIN
fi


printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED


printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH_NATIVE

printf "\n\n \e[102m ######### create 4 transactions #########\e[0m\n\n"

#----- create 4 transactions

# sender: ADDR_P2SH_P2WPKH_2
printf "\n\n \e[107m ######### P2SH-P2WPKH -> P2WPKH Native  #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2SH_P2WPKH_2'"]'`
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')
PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH_2`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_NATIVE'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')

TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "TXID: "$TXID
echo "\n"
HASH=$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
printf "hash: $HASH"
printf $HASH  > hash_1.txt


# sender: ADDR_P2SH_P2WPKH_3
printf "\n\n \e[107m ######### P2SH-P2WPKH -> P2PKH #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2SH_P2WPKH_3'"]'`
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')
PK=`bitcoin-cli dumpprivkey $ADDR_P2SH_P2WPKH_3`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2PKH'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "TXID: "$TXID
echo "\n"
HASH=$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
printf "hash: $HASH"
printf $HASH  > hash_2.txt

# sender: ADDR_P2PKH
printf "\n\n \e[107m ######### P2PKH -> P2PKH #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2PKH'"]'`
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH`
TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2PKH_2'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "TXID: "$TXID
echo "\n"
HASH=$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
printf "hash: $HASH"
printf $HASH  > hash_3.txt


# sender: ADDR_P2SH_P2WPKH
printf "\n\n \e[107m ######### P2PKH -> P2WSH NATIVE #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2PKH_2'"]'`
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.0009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH_2`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_NATIVE'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "TXID: "$TXID
echo "\n"
HASH=$(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')
printf "hash: $HASH"
printf $HASH > hash_4.txt


# Mine
printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
BLOCKS=$(bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH_NATIVE)
echo $BLOCKS | jq

#Get coinbase
bitcoin-cli getrawtransaction $(bitcoin-cli getblock $(echo $BLOCKS | jq -r '.[0]') | jq -r '.tx[0]') 2 | jq > coinbase.txt
