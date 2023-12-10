#!/bin/bash

./create_legacy_address.sh

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5

#Legacy: bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false"
bitcoin-cli -named createwallet wallet_name="bitcoin in action"

ADDR_MITT=`bitcoin-cli getnewaddress "" "legacy"`
ADDR_DEST=`cat compressed_btc_address_1.txt`

#Legacy: bitcoin-cli importprivkey `cat compressed_private_key_WIF_1.txt`
PK=$(cat compressed_private_key_WIF_1.txt)
CHECKSUM=$(bitcoin-cli -named getdescriptorinfo descriptor="pkh($PK)" | jq -r .checksum)
bitcoin-cli -named importdescriptors requests='[{ "desc": "pkh('$PK')#'"$CHECKSUM"'", "timestamp": "now", "internal": true }]'


bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' >> /dev/null

TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.01')

#Legacy: PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

#Legacy: TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')
TX_DATA_SIGNED=$(bitcoin-cli -named signrawtransactionwithwallet hexstring=$TX_DATA  | jq -r '.hex')

bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

printf  "\e[32m ######### Mine Blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
