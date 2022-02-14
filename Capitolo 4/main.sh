#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

sh create_p2sh_address.sh

#Stop, clean regtest, restart!
bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

bitcoin-cli createwallet "bitcoin in action"

ADDR_MITT=`bitcoin-cli getnewaddress "mittente" "legacy"`

#Get P2SH address
ADDR_DEST=`cat address_P2SH.txt`

#Mint 101 blocks and get reward to spend
bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
TXID=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].txid')
VOUT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].vout')
AMOUNT=$(bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.001')

#Get sender's PK
PK=`bitcoin-cli dumpprivkey $ADDR_MITT`

printf  "\n \e[31m######### TX_DATA #########\e[39m \n"
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`
bitcoin-cli decoderawtransaction $TX_DATA | jq

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m \n"
TX_DATA_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK'"]' | jq -r '.hex')
TXID=`bitcoin-cli sendrawtransaction $TX_DATA_SIGNED`
bitcoin-cli generatetoaddress 6 $ADDR_MITT

printf  "\n \e[31m######### spend from P2SH #########\e[39m \n"
AMOUNT=`bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vout[0].value-0.0001'`
VOUT=0
PK1=`cat uncompressed_private_key_WIF_1.txt`
PK2=`cat uncompressed_private_key_WIF_2.txt`
PK3=`cat uncompressed_private_key_WIF_3.txt`

# With compressed key. You must change redeem script in create_p2sh_address.sh
#PK1=`cat compressed_private_key_WIF_1.txt`
#PK2=`cat compressed_private_key_WIF_2.txt`
#PK3=`cat compressed_private_key_WIF_3.txt`

REDEEM=`cat redeem_script.txt`

#add opcode BIP0016
# A9 => OP_HASH160
# 14 => 20 bytes, 40 char hex push into the stack $(expr `echo "ibase=16; $(printf 14 | tr '[:lower:]' '[:upper:]')" | bc` "*" 2 )
# 87 => OP_EQUAL
SCRIPTPUBKEY="A914"`cat scriptPubKey.txt`"87"

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]' '[{"'$ADDR_MITT'":'$AMOUNT'},{"data":"636f72736f626974636f696e2e636f6d0a"}]')
bitcoin-cli decoderawtransaction $TX_DATA | jq

printf  "\n \e[31m######### Sign with first private key (get an error)#########\e[0m \n"
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_DATA '["'$PK1'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]'  | jq -r '.hex')
bitcoin-cli sendrawtransaction $TX_SIGNED

printf  "\n \e[31m######### Sign with second private key #########\e[0m \n"
TX_SIGNED=$(bitcoin-cli signrawtransactionwithkey $TX_SIGNED '["'$PK2'"]' '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","redeemScript":"'$REDEEM'"}]'  | jq -r '.hex')
bitcoin-cli sendrawtransaction $TX_SIGNED

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
