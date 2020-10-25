## Preparare l'ambiente.

### Per creare la transazione
Per utilizzare correttamente il file `main.sh` è necessario inserire all'interno di `tx_legacy.sh` il percorso assoluto della regtest nellavariabile `ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"` con il vostro percorso.

Eseguendo lo script `sh main.sh` sarà creata una transazione verso il miner, e successivamente verso un secondo indirizzo. 

Il secondo indirizzo effettuerà un'altra transazione firmando la transazione "manualmente", e correggendo il parametro `s` della firma se otteniamo l'errore
`non-mandatory-script-verify-flag (Non-canonical signature: S value is unnecessarily high) (code 64)`

[corsobitcoin.com](https://www.corsobitcoin.com)

--
# Setup the enviroment

TODO

[corsobitcoin.com](https://www.corsobitcoin.com)





