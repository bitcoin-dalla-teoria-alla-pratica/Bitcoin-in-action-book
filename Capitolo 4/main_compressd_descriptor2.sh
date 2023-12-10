
#!/bin/bash

#./create_p2sh_address_compressed.sh

#Stop, clean regtest, restart!
bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action"

ADDR_MITT=`bitcoin-cli getnewaddress "mittente" "legacy"`

ADDR1=$(bitcoin-cli getnewaddress)
PB1=$(bitcoin-cli getaddressinfo $ADDR1 | jq -r '.pubkey')
ADDR2=$(bitcoin-cli getnewaddress)
PB2=$(bitcoin-cli getaddressinfo $ADDR2 | jq -r '.pubkey')
#bitcoin-cli createmultisig 2 '["'$PB1'","'$PB2'"]'
#-named permette di passare i valori chiave valori
ADDR_DEST=$(bitcoin-cli -named createmultisig nrequired=2 keys='''["'$PB1'","'$PB2'"]''' | jq -r .address)

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
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_MITT'":'$AMOUNT'}]'`
bitcoin-cli -named decoderawtransaction hexstring=$TX_DATA 
TX_SIGNED=$(bitcoin-cli -named signrawtransactionwithwallet hexstring=$TX_DATA | jq -r '.hex')
bitcoin-cli -named sendrawtransaction hexstring=$TX_SIGNED
if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf  "\n \e[31m######### Send transaction and mint 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
