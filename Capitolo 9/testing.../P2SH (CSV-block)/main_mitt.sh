#!/bin/sh
ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"
if [ -z "$ABSOLUTE_PATH" ]
then
      echo "\$ABSOLUTE_PATH Please set your ABSOLUTE PATH"
      exit
fi

cd mitt && sh create_p2sh_address_mitt.sh
cd ../dest && sh create_p2sh_address_dest.sh && cd ..

bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

printf  "\n\n \e[45m ######### Mine 101 blocks #########\e[0m\n\n"
ADDR_MITT=`cat mitt/address_P2SH.txt`
ADDR_DEST=`cat dest/address_P2SH.txt`

bitcoin-cli generatetoaddress 101 $ADDR_MITT >> /dev/null
bitcoin-cli importaddress $ADDR_MITT
UTXO=`bitcoin-cli listunspent 1 101 '["'$ADDR_MITT'"]'`

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
REDEEM=`cat mitt/redeem_script.txt`
REDEEMLENGTH=$(char2hex.sh $(echo $REDEEM | wc -c))
NSEQUENCE=feffffff
NOUTPUT_AMOUNT=$(printf $TX_DATA | cut -c 93-110)

#SCRIPTPUBKEY="04ACFCD95EB175"$(printf $TX_DATA | cut -c 113-158)
SCRIPTPUBKEY=$(printf $TX_DATA | cut -c 113-158)
SCRIPTPUBKEYLENGTH=$(char2hex.sh $(printf $SCRIPTPUBKEY | wc -c))
SCRIPTPUBKEY=$SCRIPTPUBKEYLENGTH$SCRIPTPUBKEY

#potevo metterlo nel create transaction?
#LOCKTIME=ACFCD95E
LOCKTIME=00000000
SIGHASH=01000000

#Frankenstein
TX_DATA=$FIRST_PART$REDEEMLENGTH$REDEEM$NSEQUENCE$NOUTPUT_AMOUNT$SCRIPTPUBKEY$LOCKTIME$SIGHASH
printf  "\e[31m ######### TX DATA: ready to sign  #########\e[0m\n\n"
printf $TX_DATA

printf $TX_DATA | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | xxd -r -p > mitt/TX_DATA.txt
SIGNATURE=`openssl pkeyutl -inkey mitt/private_key_1.pem -sign -in mitt/TX_DATA.txt -pkeyopt digest:sha256 | xxd -p -c 256`

#Add SIGHASH
SIGNATURE="${SIGNATURE}01"
echo $SIGNATURE > mitt/signature.txt

#check if S value is unnecessarily high
printf  "\n\n \e[106m ######### Analyzing signature #########\e[0m\n\n"
cd mitt && sh fix_signature.sh >> /dev/null && cd ..
printf  "\e[31m ######### Current Signature #########\e[0m\n\n"
SIGNATURE=`cat mitt/signature.txt`
echo $SIGNATURE

SIGNATURETLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))

PBH=$(cat mitt/compressed_public_key_1.txt)
PBLENGTH=$(char2hex.sh $(printf $PBH | wc -c))
SCRIPTSIG=$(printf $SIGNATURETLENGTH$SIGNATURE$PBLENGTH$PBH$REDEEMLENGTH$REDEEM)

echo $SCRIPTSIG
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))
TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$NSEQUENCE$NOUTPUT_AMOUNT$SCRIPTPUBKEY$LOCKTIME

echo $TX_DATA_SIGNED
bitcoin-cli decoderawtransaction $TX_DATA_SIGNED | jq

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED

#btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)

echo "The last mediantime is "$(gdate --date="@$(bitcoin-cli getblock $(bitcoin-cli getbestblockhash) | jq -r '.mediantime')")"\n"
printf "\n\n \e[105m ######### mine 6 blocks #########\e[0m\n\n"
bitcoin-cli generatetoaddress 6 $ADDR_MITT
