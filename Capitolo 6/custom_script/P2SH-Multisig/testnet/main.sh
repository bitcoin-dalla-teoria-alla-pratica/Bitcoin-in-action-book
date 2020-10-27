#!/bin/sh
ABSOLUTE_PATH="$HOME/Documents/Bitcoin-in-action-book/Bitcoin"
if [ ! -d $ABSOLUTE_PATH ]
then
      echo "Error: Directory ${ABSOLUTE_PATH} does not exist. Set \$ABSOLUTE_PATH in ${0} before continue"
      exit
fi

#bitcoin-cli stop && sleep 5 && rm -Rf $ABSOLUTE_PATH/regtest && bitcoind && sleep 5

#Get BTC from faucet https://bitcoinfaucet.uo1.net/
ADDR_P2SH=`cat address_P2SH.txt`
ADDR_DEST="2NGZrVvZG92qGYqzTLjCAewvPZ7JE8S8VxE"

printf  "\e[43m ######### Start with P2SH transaction  #########\e[0m\n\n"

#ADD prameter after get bitcoin from faucet
TXID="388fcb7e731c9beff8cd02cb9395bb7bc6dcda2de7616acc4dfd505b0a9d51c4"
VOUT=0
AMOUNT=0.00012

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
sh fix_signature.sh
printf  "\e[31m ######### Current Signature #########\e[0m\n\n"
SIGNATURE=`cat signature.txt`
echo $SIGNATURE

SIGNATURETLENGTH=$(char2hex.sh $(echo $SIGNATURE | wc -c))
REDEEM=`cat redeem_script.txt`
REDEEMLENGTH=$(char2hex.sh $(echo $REDEEM | wc -c))

printf  "\n \e[31m######### Transaction data without scriptSig #########\e[39m \n"
echo $TX_DATA
printf  "\n \e[31m######### Add ScriptSig #########\e[39m \n"

## 00 workaround OP_CHECKMULTISIG
## use 4C OP_PUSHDATA1 when the data you want to push onto the stack is between 76 and 255 bytes in length, inclusive
SCRIPTSIG=$(printf "5300"$SIGNATURETLENGTH$SIGNATURE"4c"$REDEEMLENGTH$REDEEM)
SCRIPTSIGLENGTH=$(char2hex.sh $(echo $SCRIPTSIG | wc -c))
TX_DATA_SIGNED=$FIRST_PART$SCRIPTSIGLENGTH$SCRIPTSIG$LAST_PART

echo $TX_DATA_SIGNED
if [[ -n $1 ]] ; then
  btcdeb --tx=$TX_DATA_SIGNED --txin=$(bitcoin-cli getrawtransaction $TXID)
fi

printf  "\n\n \e[31m ######### Send transaction  #########\e[0m\n\n"
bitcoin-cli sendrawtransaction $TX_DATA_SIGNED
