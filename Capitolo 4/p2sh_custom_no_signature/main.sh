#!/bin/sh

#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exists. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

sh create_p2sh_address_no_signature.sh

#Stop, clean regtest, restart!
bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

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

REDEEM=`cat redeem_script.txt`

#add opcode BIP0016
# A9 => OP_HASH160
# 14 => 20 bytes, 40 char hex push into the stack $(expr `echo "ibase=16; $(printf 14 | tr '[:lower:]' '[:upper:]')" | bc` "*" 2 )
# 87 => OP_EQUAL
SCRIPTPUBKEY="A914"`cat scriptPubKey.txt`"87"

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_MITT'":'$AMOUNT'}]')
#bitcoin-cli decoderawtransaction $TX_DATA | jq

printf  "\n \e[31m######### Transaction data without scriptSig #########\e[39m \n"
echo $TX_DATA
printf  "\n \e[31m######### Add ScriptSig #########\e[39m \n"
TX_1=`printf $TX_DATA | cut -c 1-82`
TX_SCRIPTSIG=0453025387
TX_2=`printf $TX_DATA | cut -c 85-170`

echo $TX_1$TX_SCRIPTSIG$TX_2

printf  "\n \e[31m######### Send transaction #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_1$TX_SCRIPTSIG$TX_2

printf  "\n \e[31m######### Mint 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
