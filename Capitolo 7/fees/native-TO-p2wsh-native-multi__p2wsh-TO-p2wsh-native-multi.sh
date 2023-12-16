#!/bin/bash
bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5
bitcoin-cli -named createwallet wallet_name="bitcoin in action" >> /dev/null

for ((n=1;n<=3;n++))
do
 bitcoin-cli createwallet "participant_${n}" >> /dev/null
done

#Associative array
declare -A xpubs

for ((n=1;n<=3;n++))
do
 xpubs["internal_xpub_${n}"]=$(bitcoin-cli -rpcwallet="participant_${n}" listdescriptors | jq '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/1/*"))][0] | .desc' | grep -Po '(?<=\().*(?=\))')

 xpubs["external_xpub_${n}"]=$(bitcoin-cli -rpcwallet="participant_${n}" listdescriptors | jq '.descriptors | [.[] | select(.desc | startswith("wpkh") and contains("/0/*") )][0] | .desc' | grep -Po '(?<=\().*(?=\))')
done

external_desc="wsh(sortedmulti(2,${xpubs["external_xpub_1"]},${xpubs["external_xpub_2"]},${xpubs["external_xpub_3"]}))"
internal_desc="wsh(sortedmulti(2,${xpubs["internal_xpub_1"]},${xpubs["internal_xpub_2"]},${xpubs["internal_xpub_3"]}))"

external_desc_sum=$(bitcoin-cli getdescriptorinfo $external_desc | jq '.descriptor')
internal_desc_sum=$(bitcoin-cli getdescriptorinfo $internal_desc | jq '.descriptor')

multisig_ext_desc="{\"desc\": $external_desc_sum, \"active\": true, \"internal\": false, \"timestamp\": \"now\"}"
multisig_int_desc="{\"desc\": $internal_desc_sum, \"active\": true, \"internal\": true, \"timestamp\": \"now\"}"

multisig_desc="[$multisig_ext_desc, $multisig_int_desc]"


#Create the Multisig Wallet
#printf "\n\n \e[104m ######### createwallet multisig_wallet_01 disabled private keys #########\e[0m\n\n"
bitcoin-cli -named createwallet wallet_name="multisig_wallet_01" disable_private_keys=true blank=true >> /dev/null

#printf "\n\n \e[104m ######### importdescriptors  #########\e[0m\n\n"
bitcoin-cli -rpcwallet="multisig_wallet_01" importdescriptors "$multisig_desc" >> /dev/null

#printf "\n\n \e[104m ######### Get info from multisig_wallet_01  #########\e[0m\n\n"
#bitcoin-cli -rpcwallet="multisig_wallet_01" getwalletinfo
#printf "\n\n \e[104m ######### Get Receiving address from multisig_wallet_01  #########\e[0m\n\n"
ADDR_P2SH_P2WPKH_NATIVE_2=$(bitcoin-cli -rpcwallet="multisig_wallet_01" getnewaddress)


ADDR_P2SH_P2WPKH_NATIVE_1=`bitcoin-cli -rpcwallet="bitcoin in action" getnewaddress "" "bech32"`
bitcoin-cli generatetoaddress 101 $ADDR_P2SH_P2WPKH_NATIVE_1 >> /dev/null

printf "\n\n \e[104m ######### Coinbase -> P2WPKH Native -> P2WSH-P2SH (multisignature) Native  #########\e[0m\n\n"
UTXO=`bitcoin-cli -rpcwallet="bitcoin in action" listunspent 1 101 '["'$ADDR_P2SH_P2WPKH_NATIVE_1'"]'`


TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')
TOTAL_UTXO_AMOUNT=$(echo $UTXO | jq -r '.[0].amount')
REDEEMSCRIPT=$(echo $UTXO | jq -r '.[0].redeemScript')
SCRIPTPUBKEY=$(echo $UTXO | jq -r '.[0].scriptPubKey')

TX_DATA=$(bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_P2SH_P2WPKH_NATIVE_2'":'$AMOUNT'}]')
TX_SIGNED=$(bitcoin-cli -rpcwallet="bitcoin in action" signrawtransactionwithwallet $TX_DATA '[{"txid":"'$TXID'","vout":'$VOUT',"redeemScript":"'$REDEEMSCRIPT'","scriptPubKey":"'$SCRIPTPUBKEY'","amount":"'$TOTAL_UTXO_AMOUNT'"}]'  | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "txid: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.txid')\n"
printf "hash: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')\n"
printf "size: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.size')\n"
printf "vsize: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vsize')\n"
printf "weight: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.weight')\n"
printf "byte: $(expr $(printf "$TX_SIGNED" | wc -c) / 2)"

bitcoin-cli generatetoaddress 6 $ADDR_P2SH_P2WPKH_NATIVE_1 >> /dev/null

printf "\n\n \e[104m ######### P2WSH-P2SH (multisignature) Native -> P2WPKH Native  #########\e[0m\n\n"

balance=$(bitcoin-cli -rpcwallet="multisig_wallet_01" getbalance)
amount=$(echo "$balance * 0.8" | bc -l | sed -e 's/^\./0./' -e 's/^-\./-0./')
#printf "\n\n \e[104m ######### funded_psbt  #########\e[0m\n\n"
funded_psbt=$(bitcoin-cli -named -rpcwallet="multisig_wallet_01" walletcreatefundedpsbt outputs="{\"$ADDR_P2SH_P2WPKH_NATIVE_1\": $amount}" feeRate=0.0001 | jq -r '.psbt')
#1.7 Update the PSBT
psbt_1=$(bitcoin-cli -rpcwallet="participant_1" walletprocesspsbt $funded_psbt | jq '.psbt')
psbt_2=$(bitcoin-cli -rpcwallet="participant_2" walletprocesspsbt $funded_psbt | jq '.psbt')

#1.8 Combine the PSBT
#The PSBT, if signed separately by the co-signers, must be combined into one transaction before being finalized. This is done by combinepsbt RPC.
combined_psbt=$(bitcoin-cli combinepsbt "[$psbt_1, $psbt_2]")

#1.9 Finalize and Broadcast the PSBT
TX_SIGNED=$(bitcoin-cli finalizepsbt $combined_psbt | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)

printf "txid: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.txid')\n"
printf "hash: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.hash')\n"
printf "size: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.size')\n"
printf "vsize: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.vsize')\n"
printf "weight: $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.weight')\n"
printf "byte: $(expr $(printf "$TX_SIGNED" | wc -c) / 2)"
