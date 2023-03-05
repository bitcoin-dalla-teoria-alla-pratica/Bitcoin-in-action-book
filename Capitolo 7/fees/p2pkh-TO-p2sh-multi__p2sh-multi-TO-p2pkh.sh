#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" descriptors="false" >> /dev/null

ADDR_P2PKH=`bitcoin-cli getnewaddress "" "legacy"`

ADDR_1=`bitcoin-cli getnewaddress '' 'legacy'`
ADDR_2=`bitcoin-cli getnewaddress '' 'legacy'`
ADDR_P2SH=`bitcoin-cli addmultisigaddress 1 '["'$ADDR_1'","'$ADDR_2'"]' "" "legacy" | jq -r '.address'`

bitcoin-cli generatetoaddress 101 $ADDR_P2PKH >> /dev/null

printf "\n\n \e[104m ######### Coinbase -> P2PKH -> P2SH (multisignature 1-2) #########\e[0m\n\n"
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2PKH'"]'`
PK=`bitcoin-cli dumpprivkey $ADDR_P2PKH`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]'| jq -r '.hex')

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

bitcoin-cli generatetoaddress 6 $ADDR_P2PKH >> /dev/null

printf "\n\n \e[104m ######### P2SH (multisignature 1-2) -> P2PKH  #########\e[0m\n\n"
PK=`bitcoin-cli dumpprivkey $ADDR_1`
bitcoin-cli importaddress $ADDR_P2SH
UTXO=`bitcoin-cli listunspent 1 6 '["'$ADDR_P2SH'"]'`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'"}]'  | jq -r '.hex')

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
