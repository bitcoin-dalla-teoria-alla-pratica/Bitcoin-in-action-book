#https://github.com/bitcoin/bitcoin/blob/master/doc/multisig-tutorial.md
#A Simple example of Multisignature
for ((n=1;n<=3;n++))
do
 bitcoin-cli createwallet "participant_${n}"
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

printf "\n\n \e[104m ######### createwallet multisig_wallet_01 disabled private keys #########\e[0m\n\n"
bitcoin-cli -named createwallet wallet_name="multisig_wallet_01" disable_private_keys=true blank=true

printf "\n\n \e[104m ######### importdescriptors  #########\e[0m\n\n"
bitcoin-cli -rpcwallet="multisig_wallet_01" importdescriptors "$multisig_desc"

printf "\n\n \e[104m ######### Get info from multisig_wallet_01  #########\e[0m\n\n"
bitcoin-cli -rpcwallet="multisig_wallet_01" getwalletinfo


#Load wallet, non è necessario rifare tutto il procedimento sopra descritto, se non si resetta il nodo ovviamente
#for ((n=1;n<=3;n++)); do bitcoin-cli loadwallet "participant_${n}"; done

printf "\n\n \e[104m ######### Get Receiving address from multisig_wallet_01  #########\e[0m\n\n"
receiving_address=$(bitcoin-cli -rpcwallet="multisig_wallet_01" getnewaddress)

printf "\n\n \e[104m ######### Mining Blocks  #########\e[0m\n\n"
bitcoin-cli generatetoaddress 101 $receiving_address >> /dev/null

printf "\n\n \e[104m ######### Get Balances  #########\e[0m\n\n"
bitcoin-cli -rpcwallet="multisig_wallet_01" getbalances

#1.5 Create a PSBT (Partially Signed Bitcoin Transaction)
printf "\n\n \e[104m ######### Get Balance  #########\e[0m\n\n"
balance=$(bitcoin-cli -rpcwallet="multisig_wallet_01" getbalance)

printf "\n\n \e[104m ######### Get Amout  #########\e[0m\n\n"
amount=$(echo "$balance * 0.8" | bc -l | sed -e 's/^\./0./' -e 's/^-\./-0./')

printf "\n\n \e[104m ######### Set Destination Adrr  #########\e[0m\n\n"
destination_addr=$(bitcoin-cli -rpcwallet="participant_1" getnewaddress)

printf "\n\n \e[104m ######### funded_psbt  #########\e[0m\n\n"
funded_psbt=$(bitcoin-cli -named -rpcwallet="multisig_wallet_01" walletcreatefundedpsbt outputs="{\"$destination_addr\": $amount}" feeRate=0.0001 | jq -r '.psbt')


#1.6 Decode or Analyze the PSBT
bitcoin-cli decodepsbt $funded_psbt
bitcoin-cli analyzepsbt $funded_psbt


#1.7 Update the PSBT
psbt_1=$(bitcoin-cli -rpcwallet="participant_1" walletprocesspsbt $funded_psbt | jq '.psbt')
psbt_2=$(bitcoin-cli -rpcwallet="participant_2" walletprocesspsbt $funded_psbt | jq '.psbt')

#1.8 Combine the PSBT
#The PSBT, if signed separately by the co-signers, must be combined into one transaction before being finalized. This is done by combinepsbt RPC.
combined_psbt=$(bitcoin-cli combinepsbt "[$psbt_1, $psbt_2]")

#1.9 Finalize and Broadcast the PSBT
TX_SIGNED=$(bitcoin-cli finalizepsbt $combined_psbt | jq -r '.hex')
TXID=$(bitcoin-cli sendrawtransaction $TX_SIGNED)