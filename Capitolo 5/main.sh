#!/bin/sh
sh tx_legacy.sh

printf  "\n\n \e[45m ######### Start Signature #########\e[0m\n\n"

ADDR_MITT=`cat compressed_btc_address_1.txt`

TXID=`bitcoin-cli listunspent 1 6 '["'$ADDR_MITT'"]' | jq -r '.[0].txid'`
VOUT=`bitcoin-cli listunspent 1 6 '["'$ADDR_MITT'"]' | jq -r '.[0].vout'`
AMOUNT=`bitcoin-cli listunspent 1 6 '["'$ADDR_MITT'"]' | jq -r '.[0].amount-0.000009'`


ADDR_DEST=`bitcoin-cli getnewaddress "" "legacy"`
TX_DATA=`bitcoin-cli createrawtransaction '[{"txid":"'$TXID'","vout":'$VOUT'}]' '[{"'$ADDR_DEST'":'$AMOUNT'}]'`

#Save transaction's chunks
#Use ScriptPubKey like placeholder
FIRST_PART=$(printf $TX_DATA | cut -c 1-82)
SCRIPTPUB=19"$(bitcoin-cli listunspent 1 6 '["'$ADDR_MITT'"]' | jq -r '.[0].scriptPubKey')"
LAST_PART=$(printf $TX_DATA | cut -c 85-182)
SIGHASH=01000000

#Frankenstein
TX_DATA=$FIRST_PART$SCRIPTPUB$LAST_PART$SIGHASH
printf  "\e[31m ######### TX DATA: ready to sign  #########\e[0m\n\n"
printf $TX_DATA

printf $TX_DATA | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > TX_DATA.txt

#dgst -sign/-verify only does the standard single hash, so you must either hash first and then use dgst -sign/verify or hash twice and then use pkeyutl -sign/verify.
SIGNATURE=`openssl pkeyutl -inkey private_key_1.pem -sign -in TX_DATA.txt -pkeyopt digest:sha256 | xxd -p -c 256`

SIGNATURE="${SIGNATURE}01"

printf  "\n\n \e[42m ######### Send Transaction #########\e[0m\n\n"
SCRIPTLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))

#Get Public key
PB=`cat compressed_public_key_1.txt`
PBLENGTH=$(char2hex.sh $(echo $PB | wc -c))

SCRIPTSIG=$(printf $SCRIPTLENGTH$SIGNATURE$PBLENGTH$PB)
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))
TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$LAST_PART

echo $TX_DATA_SIGNED
echo "\n"
TXID_SEND=`bitcoin-cli sendrawtransaction $TX_DATA_SIGNED`

if [ ${#TXID_SEND} -eq 64 ];
then

  printf  "\e[42m ######### Valid Signature #########\e[0m\n\n"
  echo "TXID: "$TXID_SEND

  printf  "\n\n \e[105m ######### mine blocks #########\e[0m\n\n"
  bitcoin-cli generatetoaddress 6 $ADDR_MITT
  exit
else
printf  "\e[41m ######### Invalid Signature! #########\e[0m"
fi

printf  "\n\n \e[31m ######### Current SIGNATURE #########\e[0m\n\n"
echo $SIGNATURE
echo $SIGNATURE > signature.txt

printf  "\n\n \e[106m ######### Start Modify s #########\e[0m\n\n"
sh fix_signature.sh
printf  "\n\n \e[106m ######### END Modify s #########\e[0m\n\n"
printf  "\e[31m ######### New SIGNATURE #########\e[0m\n\n"
SIGNATURE=`cat signature.txt`
echo $SIGNATURE

#Get Script Length
SCRIPTLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))


SCRIPTSIG=$(printf $SCRIPTLENGTH$SIGNATURE$PBLENGTH$PB)
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))

TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$LAST_PART

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
#echo $TX_DATA_SIGNED

bitcoin-cli sendrawtransaction $TX_DATA_SIGNED
printf "\n\n \e[105m ######### mine blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT

if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi
