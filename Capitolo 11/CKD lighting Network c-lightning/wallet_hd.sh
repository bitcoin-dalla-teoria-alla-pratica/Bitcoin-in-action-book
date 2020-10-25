RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;93m"
MAGENTA="\033[1;95m"
BLU="\033[1;94m"
NOCOLOR="\033[0m"
STARTBGCOLOR="\033[41m"

if [ "$1" = 'MAINNET' ]
then
  VERSION_BYTES_PRIV=0488ADE4
  VERSION_BYTES_PUB=0488B21E
else
  VERSION_BYTES_PRIV=04358394
  VERSION_BYTES_PUB=043587CF
fi

#To check, visit https://iancoleman.io/bip39/
#paste the first xprv.
#tab BIP141.
#BIP32 m/0/0
#Script Semantics P2WPKH

#echo python wallet.py
#TODO
RES=`python wallet.py`
RES0=`printf $RES|xxd -r -p | openssl dgst -sha512 -hmac "Bitcoin seed" | awk '{print $2}'`
PK_M_LEFT=`printf $RES0 | head -c 64`
CHAIN=`printf $RES0 | tail -c 64`

printf "child private key (master) (left 256 bit) => $PK_M_LEFT \n"
printf "child chain code (right 256 bit )    => $CHAIN \n\n "

printf "🗝  Master private Key \n"
printf ${RED}$PK_M_LEFT${NOCOLOR}
printf "\n \n 🔑 Master public key compressed 264 bits\n"
MASTER_PB=`bx ec-to-public $PK_M_LEFT`

DEPTH=00
FINGERPRINT=00000000
CHAIN_NUMBER=00000000
PADDING=00
XPRV=`printf $VERSION_BYTES_PRIV$DEPTH$FINGERPRINT$CHAIN_NUMBER$CHAIN$PADDING$PK_M_LEFT`
XPRV=`printf $XPRV | xxd -p -r | base58 -c`
echo "🎋 BIP32 Root Key:${BLU}$XPRV${NOCOLOR} \n"

#A differenza della xprv: Cambio la version byte ed elimino il padding, e utilizzo la chiave pubblica a 256 bits
XPUB=`printf $VERSION_BYTES_PUB$DEPTH$FINGERPRINT$CHAIN_NUMBER$CHAIN$MASTER_PB`
XPUB=`printf $XPUB | xxd -p -r | base58 -c`
echo "🎋 BIP32 Root Public Key:${YELLOW}$XPUB${NOCOLOR} \n"

#
# ###############################################################
#
echo  "\n \n ${STARTBGCOLOR}######### DERIVATION M/0 #########${NOCOLOR}"
printf "\n\n"

#Padding
HARDENED_CHILD_PAD=00

# No Hardened
HARDENED_OFFSET_INDEX=00000000
DERIVATION=0
DERIVATION_HEX=`echo "obase=16;ibase=10; $DERIVATION" | bc`
HARDENED_INDEX=`echo "obase=16;ibase=16;$HARDENED_OFFSET_INDEX+$DERIVATION_HEX" | bc| awk '{ len = (8 - length % 8) % 8; printf "%.*s%s\n", len, "00000000", $0}'`
HMAC=$(printf $MASTER_PB$HARDENED_INDEX|xxd -r -p | openssl dgst -sha512 -hmac "`printf $CHAIN |xxd -r -p`" | awk '{print $2}')

LEFT_256_BITS=`printf $HMAC | head -c 64`
CHAIN_44=`printf $HMAC | tail -c 64`

# somma = parent private key + LEFT 256 BITS = child private key
PK=`bx ec-add-secrets $PK_M_LEFT $LEFT_256_BITS`

#printf "🗝  creo la chiave privata (child private key) m/0 \n"
#printf ${RED}$PK${NOCOLOR}

printf "\n🗝 Private Key WIF Compressed m/0 \n"
PK_WIF=`bx ec-to-wif $PK -v 239`
printf ${RED}$PK_WIF${NOCOLOR}
printf "\n \n 🔑 Compressed public key 264 bits\n"
PB_M=`bx ec-to-public $PK`
echo $PB_M > compressed_public_key_0.txt
printf ${GREEN}$PB_M${NOCOLOR};
printf "\n \n 🔑 create Segwit Address \n"
sh create_address_p2wpkh.sh > /dev/null
PB_PUBLIC=`cat address_P2WPKH.txt`
printf ${GREEN}$PB_PUBLIC${NOCOLOR};


printf  "\n\n${STARTBGCOLOR}######### DERIVATION M/0/0 #########${NOCOLOR}"
printf  "\n\n"

HARDENED_OFFSET_INDEX=00000000
DERIVATION=00
DERIVATION_HEX=`echo "obase=16;ibase=10; $DERIVATION" | bc`
HARDENED_INDEX=`echo "obase=16;ibase=16;$HARDENED_OFFSET_INDEX+$DERIVATION_HEX" | bc| awk '{ len = (8 - length % 8) % 8; printf "%.*s%s\n", len, "00000000", $0}'`

HMAC_0=$(printf $PB_M$HARDENED_INDEX|xxd -r -p | openssl dgst -sha512 -hmac "`printf $CHAIN_44 |xxd -r -p`" | awk '{print $2}')

LEFT_256_BITS=`printf $HMAC_0 | head -c 64`
CHAIN_0=`printf $HMAC_0 | tail -c 64`
PK_0=`bx ec-add-secrets $LEFT_256_BITS $PK`

#printf "🗝  private key m/0/0 \n"
#printf ${RED}$PK_0${NOCOLOR}
printf "\n🗝 Private Key WIF Compressed \n"
PK_0_WIF=`bx ec-to-wif $PK_0 -v 239`
printf ${RED}$PK_0_WIF${NOCOLOR}

printf "\n \n 🔑 Compressed public key 264 bits\n"
PB_0=`bx ec-to-public $PK_0`
printf ${GREEN}$PB_0${NOCOLOR};
printf "\n \n 🔑 Address Segwit \n"
echo $PB_0 > compressed_public_key_0.txt
sh create_address_p2wpkh.sh > /dev/null
PB_PUBLIC=`cat address_P2WPKH.txt`
printf ${GREEN}$PB_PUBLIC${NOCOLOR};

for i in {0..10}
do

printf  "\n\n${STARTBGCOLOR}######### DERIVATION M/0/0/$i #########${NOCOLOR}"
printf  "\n\n"

HARDENED_OFFSET_INDEX=00000000
DERIVATION=0$i
DERIVATION_HEX=`echo "obase=16;ibase=10; $DERIVATION" | bc`
HARDENED_INDEX=`echo "obase=16;ibase=16;$HARDENED_OFFSET_INDEX+$DERIVATION_HEX" | bc| awk '{ len = (8 - length % 8) % 8; printf "%.*s%s\n", len, "00000000", $0}'`

HMAC_0=$(printf $PB_0$HARDENED_INDEX|xxd -r -p | openssl dgst -sha512 -hmac "`printf $CHAIN_0 |xxd -r -p`" | awk '{print $2}')

LEFT_256_BITS=`printf $HMAC_0 | head -c 64`
CHAIN=`printf $HMAC_0 | tail -c 64`
PK=`bx ec-add-secrets $LEFT_256_BITS $PK_0`

#printf "🗝  private key m/0/0 \n"
#printf ${RED}$PK_0${NOCOLOR}
printf "\n🗝 Private Key WIF Compressed \n"
PK_0_WIF=`bx ec-to-wif $PK -v 239`
printf ${RED}$PK_WIF${NOCOLOR}
printf "\n \n 🔑 Compressed public key 264 bits\n"
PB=`bx ec-to-public $PK`
printf ${GREEN}$PB${NOCOLOR};
printf "\n \n 🔑 Address Segwit \n"
echo $PB > compressed_public_key_0.txt
sh create_address_p2wpkh.sh > /dev/null
PB_PUBLIC=`cat address_P2WPKH.txt`
printf ${GREEN}$PB_PUBLIC${NOCOLOR};
printf  "\n\n"
done

rm -rf compressed_public_key_0.txt scriptPubKey_0.txt group.txt base10.txt base2.txt
