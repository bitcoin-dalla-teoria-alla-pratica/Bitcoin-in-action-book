#!/bin/bash

./create_legacy_address.sh

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false"

ADDR_MITT=`bitcoin-cli getnewaddress "mittente" "legacy"`
ADDR_DEST=`cat uncompressed_btc_address_1.txt`

bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null

TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.001')

#echo $AMOUNT
PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
#echo "\n"
#echo $PK

printf  "\n \e[31m######### TX_DATA #########\e[0m \n"
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`
printf $TX_DATA

#Insert 2-3 in TX_DATA
TX_DATA_INIT=`echo $TX_DATA | cut -c 1-110`
UNCOMPRESSED_PB1=`cat uncompressed_public_key_1.txt`
UNCOMPRESSED_PB2=`cat uncompressed_public_key_2.txt`
UNCOMPRESSED_PB3=`cat uncompressed_public_key_3.txt`

#M-N 2-3
#C9 ScriptPubkey/Locking script Length
#52 OP_2, require two signature
#41 bytes (130 char hex)
#53 OP_3, three public keys can check the signature
#AE OP_CHECKMULTISIG
printf  "\n \e[31m######### TX_DATA with Multi-sig #########\e[0m \n"
TX_DATA=`printf $TX_DATA_INIT"C95241"$UNCOMPRESSED_PB1"41"$UNCOMPRESSED_PB2"41"$UNCOMPRESSED_PB3"53AE00000000"`
echo "$TX_DATA"

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m \n"
TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')
TXID=`bitcoin-cli sendrawtransaction $TX_DATA_SIGNED`
bitcoin-cli generatetoaddress 6 $ADDR_MITT

printf  "\n \e[31m######### spend from P2MS #########\e[0m \n"
AMOUNT=`bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vout[0].value-0.0001'`
VOUT=0
UNCOMPRESSED_PK1=`cat uncompressed_private_key_WIF_1.txt`
UNCOMPRESSED_PK2=`cat uncompressed_private_key_WIF_2.txt`
UNCOMPRESSED_PK3=`cat uncompressed_private_key_WIF_3.txt`

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_MITT'":'$AMOUNT'}]')
#echo $TX_DATA

printf  "\n \e[31m######### Sign with first private key #########\e[0m \n"
TX_SIGNED1=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$UNCOMPRESSED_PK1'"]')
echo $TX_SIGNED1 | jq
TX_SIGNED1=$(echo $TX_SIGNED1 | jq -r '.hex')

printf  "\n \e[31m######### Sign with second private key #########\e[0m \n"
TX_SIGNED2=$(bitcoin-cli signrawtransactionwithkey $TX_SIGNED1 '["'$UNCOMPRESSED_PK2'"]')
echo $TX_SIGNED2 |jq
TX_SIGNED2=$(echo $TX_SIGNED2 | jq -r '.hex')
printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED2
bitcoin-cli generatetoaddress 6 $ADDR_MITT
