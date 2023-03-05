#!/bin/bash

printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_MITT=`cat dest/address_P2SH.txt`
ADDR_DEST=`cat mitt/address_P2SH.txt`

bitcoin-cli importaddress $ADDR_MITT
UTXO=`bitcoin-cli listunspent 1 9999 '["'$ADDR_MITT'"]'`

printf  "\e[43m ######### Start with P2SH transaction  #########\e[0m\n\n"
TXID=$(echo $UTXO | jq -r '.[0].txid')
VOUT=$(echo $UTXO | jq -r '.[0].vout')
AMOUNT=$(echo $UTXO | jq -r '.[0].amount-0.009')

TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

printf  "\e[43m ######### TX DATA without signature #########\e[0m\n\n"
echo $TX_DATA
#Save transaction's chunks
#Use Redeem script like placeholder
#txin (outpoint+signature) 
#[version]      [outpoint][signature][txout]         [locktime] <-- P2PKH
# "051588778843B175"
# FIRST_PART=$(printf $TX_DATA | cut -c 1-82)
# REDEEM=`cat redeem_script.txt`
# REDEEMLENGTH=$(char2hex.sh $(echo $REDEEM | wc -c))
# NSEQUENCE=$(printf $TX_DATA | cut -c 85-92)
# AMOUNT=$(printf $TX_DATA | cut -c 93-110) #amount + numero output
# SCRIPTPUBKEY=$(printf $TX_DATA | cut -c 110-162)
# #LAST_PART=$(printf $TX_DATA | cut -c 93-182)
# LOCKTIME=5BD7B25E
# SIGHASH=01000000
# #Frankenstein
# TX_DATA=$FIRST_PART$REDEEMLENGTH$REDEEM$NSEQUENCE$AMOUNT"051588778843B175"$SCRIPTPUBKEY$LOCKTIME$SIGHASH
# printf  "\e[31m ######### TX DATA: ready to sign  #########\e[0m\n\n"
# printf $TX_DATA


# $ gdate --date='2020-06-05 10:05:00' +%s
# 1591344300


FIRST_PART=$(printf $TX_DATA | cut -c 1-82)
REDEEM=`cat dest/redeem_script.txt`
REDEEMLENGTH=$(char2hex.sh $(echo $REDEEM | wc -c))
#little endian, padding ricordatelo
NSEQUENCE=C8000000
NOUTPUT_AMOUNT=$(printf $TX_DATA | cut -c 93-110)

#SCRIPTPUBKEY="04ACFCD95EB175"$(printf $TX_DATA | cut -c 113-158)
SCRIPTPUBKEY=$(printf $TX_DATA | cut -c 113-158)
SCRIPTPUBKEYLENGTH=$(char2hex.sh $(printf $SCRIPTPUBKEY | wc -c))
SCRIPTPUBKEY=$SCRIPTPUBKEYLENGTH$SCRIPTPUBKEY

#potevo metterlo nel create transaction? (SI)
#LOCKTIME=ACFCD95E
#LOCKTIME=00000000
#LOCKTIME=00000000
#ATTENZIONE printf tac -rs se ha due zeri non li mette?
LOCKTIME=00000000
SIGHASH=01000000

#Frankenstein
TX_DATA=$FIRST_PART$REDEEMLENGTH$REDEEM$NSEQUENCE$NOUTPUT_AMOUNT$SCRIPTPUBKEY$LOCKTIME$SIGHASH
printf  "\e[31m ######### TX DATA: ready to sign  #########\e[0m\n\n"
printf $TX_DATA

printf $TX_DATA | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > dest/TX_DATA.txt
SIGNATURE=`openssl pkeyutl -inkey dest/private_key_1.pem -sign -in dest/TX_DATA.txt -pkeyopt digest:sha256 | xxd -p -c 256`

#Add SIGHASH
SIGNATURE="${SIGNATURE}01"
echo $SIGNATURE > dest/signature.txt

#check if S value is unnecessarily high
printf  "\n\n \e[106m ######### Analyzing signature #########\e[0m\n\n"
cd dest && ./fix_signature.sh >> /dev/null && cd ..
printf  "\e[31m ######### Current Signature #########\e[0m\n\n"
SIGNATURE=`cat dest/signature.txt`
echo $SIGNATURE

SIGNATURETLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))

PBH=$(cat dest/compressed_public_key_1.txt)
PBLENGTH=$(char2hex.sh $(printf $PBH | wc -c))
SCRIPTSIG=$(printf $SIGNATURETLENGTH$SIGNATURE$PBLENGTH$PBH$REDEEMLENGTH$REDEEM)

echo $SCRIPTSIG
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))
TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$NSEQUENCE$NOUTPUT_AMOUNT$SCRIPTPUBKEY$LOCKTIME

echo $TX_DATA_SIGNED
bitcoin-cli decoderawtransaction $TX_DATA_SIGNED | jq

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

printf "\n \e[41m ######### Le conferme del blocco da dove parte la UTXO sono: "$(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.confirmations')" e sono richieste almeno 200 #########\e[0m\n\n"

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi


printf "\n\n \e[105m ######### mine 194 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 194 $ADDR_MITT >> /dev/null

printf "\n \e[42m ######### Le conferme del blocco da dove parte la UTXO sono: "$(bitcoin-cli getblock $(bitcoin-cli getrawtransaction $TXID 2 | jq -r '.blockhash') | jq -r '.confirmations')" e sono richieste almeno 200 #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED
