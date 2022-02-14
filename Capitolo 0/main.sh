#!/bin/sh

if [ $# -ge 1 ]
then
    VERSION=$1
    SO=$2
else
    VERSION=22.0
    SO=osx64
fi

printf "\e[32m ######### Hello, "$USER".  Are you ready for Bitcoin World? #########\e[0m\n\n"

printf "\n\n \e[101m ######### Download Bitcoin core #########\e[0m\n\n"
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-$SO.tar.gz

printf "\n\n \e[101m ######### Download Checksum #########\e[0m\n\n"
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc

printf "\n\n \e[42m ######### Checking Cheksum #########\e[0m\n\n"
sha256sum --check SHA256SUMS.asc --ignore-missing

printf "\n\n \e[101m ######### Download Wladimir J. van der Laan's Public key #########\e[0m\n\n"
wget https://bitcoin.org/laanwj-releases.asc

printf "\n\n \e[101m ######### Import Public key (check PGP) #########\e[0m\n\n"
gpg --import laanwj-releases.asc

printf "\n\n \e[42m ######### check the signature #########\e[0m\n\n"
gpg --verify SHA256SUMS.asc

printf "\n\n \e[101m ######### Extract the package#########\e[0m\n\n"
tar -xvf bitcoin-$VERSION-$SO.tar.gz

printf "\n\n \e[101m ######### Checking the "\$PATH" #########\e[0m\n\n"
echo $PATH

printf '\e[32mCopy bin/bitcoin* in /usr/local/bin/ (check if /usr/local/bin/ is in your $PATH)\e[0m\n\n'
sudo cp bitcoin-$VERSION/bin/bitcoin* /usr/local/bin/.

printf "\n\n \e[42m ######### Check Bitcoin core version  #########\e[0m\n\n"
bitcoind -version

printf "\n\n \e[42m ######### Check the path #########\e[0m\n\n"
which -a bitcoind

printf '\e[32m Cleaning \e[0m\n\n'
rm SHA256SUMS.asc bitcoin-$VERSION-$SO.tar.gz laanwj-releases.asc
rm -Rf bitcoin-$VERSION/
echo "\n"
printf "\e[43mBitcoin In Action 🚀\e[0m "
