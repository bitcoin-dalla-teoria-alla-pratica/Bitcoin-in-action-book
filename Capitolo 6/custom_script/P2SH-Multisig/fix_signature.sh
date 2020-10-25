#!/bin/sh

SIGNATURE=`cat signature.txt`

DER_PREFIX=`printf $SIGNATURE | cut -c 1-2`
echo "\n DER Prefix: `printf $DER_PREFIX`"
LENGTH_SIGN=`printf $SIGNATURE | cut -c 3-4`
echo "\n Length of rest of Signature: `printf $LENGTH_SIGN`"

printf  "\n\n \e[31m ######### R #########\e[0m\n\n"
MARK_R=`printf $SIGNATURE | cut -c 5-6`
echo "\n Marker for r value: `printf $MARK_R`"
R_LENGTH=`printf $SIGNATURE | cut -c 7-8`
echo "\n Length of r value: `printf $R_LENGTH`"
r=`printf $SIGNATURE | cut -c 7-8`
r_length=$(hex2char.sh $r)
  #echo "\t" $r_length "hex char"
r_end=$((8 + $r_length))
R=`printf $SIGNATURE | cut -c 9-$r_end`
echo "\n r: `printf $R`"

printf  "\n\n \e[32m ######### S #########\e[0m\n\n"
pointer=$(echo $(($r_end + 1)))
MARK_S=`printf $SIGNATURE | cut -c $pointer-$(($pointer + 1))`
echo "\n Marker for s value: `printf $MARK_S`"
S_LENGTH=`printf $SIGNATURE | cut -c $(($pointer + 2))-$(($pointer + 3))`
echo "\n Length of s value: `printf $S_LENGTH`"
s_length=`printf $SIGNATURE | cut -c $(($pointer + 2))-$(($pointer + 3))`
s_length=$(hex2char.sh $s_length)
#  echo "\t" $s_length "hex char"
  s_end=$(($pointer + 4 + $s_length - 1))
S=`printf $SIGNATURE | cut -c $(($pointer + 4))-$s_end`
echo "\n s: `printf $S`"

printf  "\n\n \e[33m ##################\e[0m\n\n"
SIGHASH_ALL=`printf $SIGNATURE | cut -c $(($s_end +1))-$(($s_end +2))`
echo "\n SIGHASH_ALL: `printf $SIGHASH_ALL`"


#printf  "\n\n \e[34m ######### Convert s to base10 ######### \e[0m\n\n"
s=`echo "ibase=16; $(printf $S  | tr '[:lower:]' '[:upper:]')" | bc |  tr -d '\n' | tr -d '\' | awk '{print $1}'`

N=`echo "ibase=16;FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141" | bc  |  tr -d '\n' | tr -d '\' | awk '{print $1}'`
N2=`echo "$N/2" | bc -l |  tr -d '\n' | tr -d '\' | awk '{print $1}'`

#echo $s
#echo "/n"
#echo $N2

#check if s is greater than N2
if (( $(bc <<< "$s > $N2") ));
then
printf  "\n\e[106m S value is unnecessarily high 😔 #########\e[0m\n"
printf  "\e[106m Changing s \e[0m\n\n"
#subtract
s=`echo "$N - $s" | bc |  tr -d '\n' | tr -d '\' | awk '{print $1}'`

#convert to base10
s=`echo "obase=16;$s" | bc`
s_length=`printf $s | wc -c`

# signature must be even. If odd, add 0 at the beginning
if [ $(($s_length%2)) -ne 0 ]
then
  s=`printf "0"$s`
fi
#get length
s_new_length=`char2hex.sh $(echo $s | wc -c)`

#printf $s
#echo "\n"
#printf $s_new_length

#get Length of rest of Signature
new_LENGTH_SIGN=`char2hex.sh $(echo $MARK_R$R_LENGTH$R$MARK_S$s_new_length$s | wc -c)`
#Frankestein ! :)
SIGNATURE=`echo $DER_PREFIX$new_LENGTH_SIGN$MARK_R$R_LENGTH$R$MARK_S$s_new_length$s$SIGHASH_ALL`

#echo $SIGNATURE

else
    printf  "\n\n \e[102m ######### Good signature! No change needed #########\e[0m\n\n"
    #echo $SIGNATURE
fi
echo $SIGNATURE > signature.txt
