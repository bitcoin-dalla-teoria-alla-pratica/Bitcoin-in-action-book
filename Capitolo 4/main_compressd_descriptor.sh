#!/bin/bash

./create_p2sh_address_compressed.sh

#Stop, clean regtest, restart!
bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5

bitcoin-cli -named createwallet wallet_name="bitcoin in action"

ADDR_MITT=`bitcoin-cli getnewaddress "mittente" "legacy"`

#Get P2SH address
ADDR_DEST=`cat address_P2SH.txt`

#Mint 101 blocks and get reward to spend
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.001')


printf  "\n \e[31m######### TX_DATA #########\e[39m \n"
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`
bitcoin-cli decoderawtransaction $TX_DATA | jq

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m \n"
#Get sender's PK (Legcy Wallet no descriptor)
#PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
# TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')
TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithwallet $TX_DATA | jq -r '.hex')
TXID=`bitcoin-cli sendrawtransaction $TX_DATA_SIGNED`
bitcoin-cli generatetoaddress 6 $ADDR_MITT

printf  "\n \e[31m######### spend from P2SH #########\e[39m \n"
AMOUNT=`bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vout[0].value-0.0001'`
VOUT=0

# With compressed key. You must change redeem script in create_p2sh_address.sh
PK1=`cat compressed_private_key_WIF_1.txt`
PK2=`cat compressed_private_key_WIF_2.txt`
PK3=`cat compressed_private_key_WIF_3.txt`

#wsh(multi(2,KEY1,KEY2,KEY3))
CHECKSUM=$(bitcoin-cli getdescriptorinfo "sh(multi(2,$PK1,$PK2,$PK3))" | jq -r .checksum)
bitcoin-cli importdescriptors '[{ "desc": "sh(multi(2,'$PK1','$PK2','$PK3'))#'$CHECKSUM'", "timestamp": "now", "internal": true }]'
#DEBUG
# DESC=$(bitcoin-cli getdescriptorinfo "sh(multi(2,$PK1,$PK2,$PK3))" | jq -r .descriptor)
# bitcoin-cli deriveaddresses $DESC
# printf $(cat address_P2SH.txt)
# ADDR=$(bitcoin-cli deriveaddresses $DESC | jq -r '.[0]')
# bitcoin-cli getaddressinfo $ADDR


REDEEM=`cat redeem_script.txt`

#add opcode BIP0016
# A9 => OP_HASH160
# 14 => 20 bytes, 40 char hex push into the stack $(expr `echo "ibase=16; $(printf 14 | tr '[:lower:]' '[:upper:]')" | bc` "*" 2 )
# 87 => OP_EQUAL
SCRIPTPUBKEY="A914"`cat scriptPubKey.txt`"87"

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]' '[{"'$ADDR_MITT'":'$AMOUNT'},{"data":"636f72736f626974636f696e2e636f6d0a"}]')
# bitcoin-cli decoderawtransaction $TX_DATA | jq
TX_SIGNED=$(bitcoin-cli signrawtransactionwithwallet $TX_DATA '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]'  | jq -r '.hex')


if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
