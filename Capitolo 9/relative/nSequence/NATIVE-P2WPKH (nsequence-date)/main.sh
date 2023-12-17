#!/bin/bash


bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5

bitcoin-cli -named createwallet wallet_name="bitcoin in action"
ADDR_MITT=`bitcoin-cli getnewaddress "" "bech32"`
ADDR_DEST=`bitcoin-cli getnewaddress "" "bech32"`

bitcoin-cli generatetoaddress 102 $ADDR_MITT >> /dev/null

#GET UTXO with 101 Confirmations
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]'`

TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

SEC=512
BIN=$(512to2.py $SEC)
SEQUENCE=`echo 'ibase=2; 0000000001000000'$BIN | bc`
TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT',"sequence":'$SEQUENCE'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli signrawtransactionwithwallet $TX_DATA '[{"txid":"'$TXID'","vout":'$VOUT',"scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
#bitcoin-cli decoderawtransaction $TX_SIGNED

PREVIOUS_MEDIAN_TIME=$(bitcoin-cli getblock $(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.previousblockhash') | jq -r '.mediantime')
MEDIANTIME_UTXO=$(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.mediantime')
CURRENT_MEDIANTIME=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime')

printf "\n \e[44m ######### The previous block's mediantime is: "$(tohuman.py $PREVIOUS_MEDIAN_TIME )" \n- Block UTXO's mediantime is "$(tohuman.py $MEDIANTIME_UTXO)" \n- The transaction is valid after $SEC seconds. Date:"$(tohuman.py $(forwardseconds.py $SEC $MEDIANTIME_UTXO)) " \n- bestblock's mediantime" $(tohuman.py $CURRENT_MEDIANTIME)" #########\e[0m\n\n"

printf "\n \e[41m ######### Error #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_SIGNED

# echo "\n ---------"
# echo "0)🏃🏃🏻‍♂️ ARE YOU IN A HURRY? Dont wait "$(echo $SEC)" seconds."
# echo "1)The difference between bestblock's mediantime and previous block's mediantime is: "$(expr $CURRENT_MEDIANTIME - $PREVIOUS_MEDIAN_TIME)" The result must be >= "$(echo $SEC)
# echo '2)MOVE YOUR CLOCK @' $(tohuman.py $(forwardseconds.py $SEC)) 'or bitcoin-cli setmocktime $(date +%s -d 'now + 7 min') '
# echo '3)Execute => bitcoin-cli generatetoaddress 11 $(bitcoin-cli getnewaddress "" "bech32") >> /dev/null'
# echo '4)Execute => bitcoin-cli sendrawtransaction '$(echo $TX_SIGNED)
# echo '...OR WAIT 🤷🏻‍♂️'
# echo "---------\n"

# printf "\n \e[41m ######### Waiting... ⏳ #########\e[0m\n\n"
# secs=$((1 * $SEC))
# while [ $secs -gt 0 ]; do
#    printf "$secs\n"
#    sleep 1
#    : $((secs--))
# done

printf "\n \e[44m ######### Moving the bitcoind time (9 mins) #########\e[0m\n\n"
bitcoin-cli setmocktime $(date +%s -d 'now + 9 min')

bitcoin-cli generatetoaddress 11 $ADDR_MITT >> /dev/null
printf "\n \e[42m ######### Done! #########\e[0m\n\n"
CURRENT_MEDIANTIME=$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime')
echo "The difference between bestblock's mediantime and previous block's mediantime is: "$(expr $CURRENT_MEDIANTIME - $PREVIOUS_MEDIAN_TIME)" The result must be >= "$(echo $SEC)
bitcoin-cli sendrawtransaction $TX_SIGNED

bitcoin-cli setmocktime 0
