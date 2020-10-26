#!/bin/sh
printf  "\e[101m######### TRANSACTION MALLEABILITY #########\e[0m \n"

ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind -acceptnonstdtxn=1 && sleep 5
ADDR_MITT=`bitcoin-cli getnewaddress "malleability mittente" "legacy"`
ADDR_DEST=`bitcoin-cli getnewaddress "malleability destinatario" "legacy"`

bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null

TXID_UNSPENT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.001')

PK=`bitcoin-cli dumpprivkey $ADDR_MITT`

printf  "\n \e[31m######### TX_DATA UNSIGNED #########\e[0m \n"
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID_UNSPENT'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`
printf $TX_DATA

printf  "\n\n \e[31m######### Sign the transaction #########\e[0m \n"
TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')

printf  "\n \e[31m######### TX_DATA SIGNED #########\e[0m \n"
printf $TX_DATA_SIGNED

bitcoin-cli decoderawtransaction $TX_DATA_SIGNED | jq
printf  "\n\n \e[31m######### TX ID #########\e[0m \n"
TXID=$(printf `printf $TX_DATA_SIGNED | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b` | tac -rs ..)
echo $TXID

PART_1=$(printf $TX_DATA_SIGNED | cut -c 1-82)
NEW_SCRIPTSIG_LENGTH=6c
SCRIPTSIG=$(printf $TX_DATA_SIGNED | cut -c 85-296)
OPERATION=5275
PART_2=$(printf $TX_DATA_SIGNED | cut -c 297-382)


printf  "\n\n \e[31m######### Transaction Data With Extra Operation (OP_2 OP_DROP) #########\e[0m \n"
printf $PART_1$NEW_SCRIPTSIG_LENGTH$SCRIPTSIG$OPERATION$PART_2
TXMALL=$PART_1$NEW_SCRIPTSIG_LENGTH$SCRIPTSIG$OPERATION$PART_2

printf  "\n\n \e[31m######### New TX ID #########\e[0m \n"
TXID_MALL=$(printf `printf $TXMALL | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b` | tac -rs ..)
echo $TXID_MALL

bitcoin-cli decoderawtransaction $TXMALL | jq

printf  "\n\n \e[31m######### Compare TX IDs #########\e[0m \n"
printf "Original TXID\n"$TXID"\n"
printf "TXID transaction malleability\n"$TXID_MALL

printf  "\n\n \e[31m######### Send transaction with extra Op code #########\e[0m \n"
bitcoin-cli sendrawtransaction $TXMALL

#btcdeb --tx=$TXMALL --txin=$(bitcoin-cli getrawtransaction $TXID_UNSPENT)
