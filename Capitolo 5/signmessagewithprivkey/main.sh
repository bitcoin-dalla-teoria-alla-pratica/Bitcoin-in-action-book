#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false"
ADDR_MITT=`bitcoin-cli getnewaddress "" "legacy"`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' >> /dev/null
TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.01')
PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

SIGNATURE=`bitcoin-cli signmessagewithprivkey $PK $TX_DATA`
echo $SIGNATURE

printf $SIGNATURE | base64 -d | xxd -p |  tr -d '\n' | awk '{print $1}'

printf  "\e[31m ######### verifymessage #########\e[0m\n\n"
bitcoin-cli verifymessage $ADDR_MITT $SIGNATURE $TX_DATA
