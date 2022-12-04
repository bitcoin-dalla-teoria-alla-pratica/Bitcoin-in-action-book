#!/bin/bash

# https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#commitment-structure
# 1-byte - OP_RETURN (0x6a)
# 1-byte - Push the following 36 bytes (0x24)
# 4-byte - Commitment header (0xaa21a9ed)
# 32-byte - Commitment hash: Double-SHA256(witness root hash|witness reserved value)
#
# 39th byte onwards: Optional data with no consensus meaning
./create_transactions.sh

printf  "\n\n \e[41m ######### Creating Segregated merkle tree #########\e[0m\n\n"
COMMITMENT_STRUCTURE=$(cat coinbase.txt | jq -r '.vout[1].scriptPubKey.hex' | cut -c 13-78)

WITNESS_ROOT_HASH=0000000000000000000000000000000000000000000000000000000000000000
H1=$(cat hash_1.txt | tac -rs ..)
H2=$(cat hash_2.txt | tac -rs ..)
H3=$(cat hash_3.txt | tac -rs ..)
H4=$(cat hash_4.txt | tac -rs ..)
WITNESS_RESERVED_VALUE=0000000000000000000000000000000000000000000000000000000000000000

RES1=$(printf $WITNESS_ROOT_HASH$H1 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
RES2=$(printf $H2$H3 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
RES3=$(printf $H4$H4 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')

RES5=$(printf $RES1$RES2 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')
RES6=$(printf $RES3$RES3 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')

RES7=$(printf $RES5$RES6 | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')

RES8=$(printf $RES7$WITNESS_RESERVED_VALUE | xxd -r -p | sha256sum -b | xxd -r -p | sha256sum -b | awk '{print $1}')


test $RES8 = $COMMITMENT_STRUCTURE  && echo they are the same! || echo ops, they are differents!

echo "\n ---- values ---"
echo "RES8:" $RES8
echo "COMMITMENT_STRUCTURE:" $COMMITMENT_STRUCTURE
