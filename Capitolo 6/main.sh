#!/bin/bash


#create address 1-3
./create_p2sh_address.sh

bitcoin-cli stop && sleep 5 && rm -Rf $HOME/.bitcoin/regtest && bitcoind && sleep 5

bitcoin-cli -named createwallet wallet_name="bitcoin in action"
printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_P2SH=`cat address_P2SH.txt`
ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`

#bitcoin-cli importaddress $ADDR_P2SH
PK1=`cat compressed_private_key_WIF_1.txt`
PK2=`cat compressed_private_key_WIF_2.txt`
PK3=`cat compressed_private_key_WIF_3.txt`
CHECKSUM=$(bitcoin-cli getdescriptorinfo "sh(multi(1,$PK1,$PK2,$PK3))" | jq -r .checksum)
bitcoin-cli importdescriptors '[{ "desc": "sh(multi(1,'$PK1','$PK2','$PK3'))#'$CHECKSUM'", "timestamp": "now", "internal": true }]'

#DEBUG
#PK1=`cat compressed_private_key_WIF_1.txt`
#PK2=`cat compressed_private_key_WIF_2.txt`
#PK3=`cat compressed_private_key_WIF_3.txt`
#DESC=$(bitcoin-cli getdescriptorinfo "sh(multi(1,$PK1,$PK2,$PK3))" | jq -r .descriptor)
#bitcoin-cli deriveaddresses $DESC
#printf $(cat address_P2SH.txt)
#ADDR=$(bitcoin-cli deriveaddresses $DESC | jq -r '.[0]')
#bitcoin-cli getaddressinfo $ADDR



bitcoin-cli generatetoaddress 101 $ADDR_P2SH >> /dev/null

UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_P2SH'"]'`

printf  "\e[43m ######### Start with P2SH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

printf  "\e[43m ######### TX DATA without signature #########\e[0m\n\n"
echo $TX_DATA
#Save transaction's chunks
#Use Redeem script like placeholder
FIRST_PART=$(printf $TX_DATA | cut -c 1-82)
REDEEM=`cat redeem_script.txt`
REDEEMLENGTH=$(char2hex.sh $(echo $REDEEM | wc -c))
LAST_PART=$(printf $TX_DATA | cut -c 85-182)
SIGHASH=01000000

#Frankenstein
TX_DATA=$FIRST_PART$REDEEMLENGTH$REDEEM$LAST_PART$SIGHASH
printf  "\e[31m ######### TX DATA: ready to sign  #########\e[0m\n\n"
printf $TX_DATA

printf $TX_DATA | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > TX_DATA.txt
SIGNATURE=`openssl pkeyutl -inkey private_key_1.pem -sign -in TX_DATA.txt -pkeyopt digest:sha256 | xxd -p -c 256`

#Add SIGHASH
SIGNATURE="${SIGNATURE}01"
echo $SIGNATURE > signature.txt

#check if S value is unnecessarily high
printf  "\n\n \e[106m ######### Analyzing signature #########\e[0m\n\n"
./fix_signature.sh
printf  "\e[31m ######### Current Signature #########\e[0m\n\n"
SIGNATURE=`cat signature.txt`
echo $SIGNATURE

SIGNATURETLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))

## 00 workaround OP_CHECKMULTISIG
## use 4C OP_PUSHDATA1 when the data you want to push onto the stack is between 76 and 255 bytes in length, inclusive
SCRIPTSIG=$(printf "00"$SIGNATURETLENGTH$SIGNATURE"4c"$REDEEMLENGTH$REDEEM)
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))
TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$LAST_PART

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_P2SH
