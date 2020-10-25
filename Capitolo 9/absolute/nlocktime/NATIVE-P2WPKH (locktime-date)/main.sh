#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
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


#gdate --date 'now - 10 days'
##Now + 20 seconds by default
TIME=`forwardseconds.py`
TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]' $TIME)
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
echo $TX_SIGNED

# echo "Today is ("$(gdate --date 'now')") and the transaction is valid from "$(gdate --date='@'$TIME'') "\n"
#
# bitcoin-cli sendrawtransaction $TX_SIGNED
# TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
# printf "\n \e[42m ######### Consume the same UTXO #########\e[0m\n\n"
# TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
# echo $TX_SIGNED

#Deve essere MAGGIORE del median Time
printf "\n \e[41m ######### ALERT #########\e[0m\n\n"
echo "The last mediantime is "$(tohuman.py $(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime'))" and the transaction is valid from "$(tohuman.py $TIME) "\n"

bitcoin-cli sendrawtransaction $TX_SIGNED

printf "\n \e[41m ######### Waiting... ⏳ #########\e[0m\n\n"
secs=$((1 * 60))
while [ $secs -gt 0 ]; do
   printf "$secs\n"
   sleep 1
   : $((secs--))
done

bitcoin-cli generatetoaddress 11 $ADDR_MITT >> /dev/null
echo "The last mediantime is "$(tohuman.py $(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime'))" and the transaction is valid from "$(tohuman.py $TIME) "\n"

echo $TX_SIGNED
bitcoin-cli decoderawtransaction $TX_SIGNED

bitcoin-cli sendrawtransaction $TX_SIGNED
