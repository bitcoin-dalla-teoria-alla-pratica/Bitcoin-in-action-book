#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action"
ADDR_MITT=`bitcoin-cli getnewaddress "" "legacy"`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' >> /dev/null
TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.01')
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

#Legacy
#PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
#SIGNATURE=`bitcoin-cli signmessagewithprivkey $PK $TX_DATA`

printf  "\e[32m ######### Sign Message #########\e[0m\n\n"
SIGNATURE=`bitcoin-cli -named signmessage address=$ADDR_MITT message=$TX_DATA`

printf  "\e[32m ######### Signature #########\e[0m\n\n"
echo $SIGNATURE

printf  "\e[32m ######### Signature base64 #########\e[0m\n\n"
printf $SIGNATURE | base64 -d | xxd -p |  tr -d '\n' | awk '{print $1}'

printf  "\e[31m ######### verifymessage #########\e[0m\n\n"
bitcoin-cli -named verifymessage address=$ADDR_MITT signature=$SIGNATURE message=$TX_DATA
