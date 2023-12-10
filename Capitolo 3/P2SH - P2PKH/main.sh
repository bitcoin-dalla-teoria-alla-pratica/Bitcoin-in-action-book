#!/bin/bash

./create_p2sh_address_p2pkh.sh

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action"

printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_P2SH=`cat address_P2SH.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`
#IMPORT ADDRESS DESCRIPTOR
#bitcoin-cli importaddress $ADDR_P2SH
CHECKSUM=$(bitcoin-cli getdescriptorinfo "sh(pkh($(cat compressed_private_key_WIF_1.txt)))" | jq -r .checksum)
bitcoin-cli importdescriptors '[{ "desc": "sh(pkh('$(cat compressed_private_key_WIF_1.txt)'))#'"$CHECKSUM"'", "timestamp": "now", "internal": true }]'
bitcoin-cli generatetoaddress 101 $ADDR_P2SH >> /dev/null
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH'"]'`



printf  "\e[43m ######### Start with P2SH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TXIN=`bitcoin-cli getrawtransaction $TXID`

#PK=`cat compressed_private_key_WIF_1.txt`
REDEEM=`cat redeem_script.txt`
SCRIPTPUBKEY="A914"`cat scriptPubKey.txt`"87"

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
#Get sender's PK (Legcy Wallet no descriptor)
#PK=`bitcoin-cli dumpprivkey $ADDR_MITT`
#TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]'  | jq -r '.hex')
TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithwallet $TX_DATA '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]'  | jq -r '.hex')

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$TXIN
fi

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH
