## Preparare l'ambiente.

### Per creare la transazione
Per utilizzare correttamente il file `main.sh` è necessario cambiare la variabile `ABSOLUTE_PATH="/Users/barno/Documents/bizantino/Bitcoin"` con il vostro percorso.

Eseguendo lo script `sh main.sh` sarà creato un address P2SH con redeem script 1-3 (una firma necessaria e 3 chiavi pubbliche su cui verificare) OP_DROP OP_3 OP_EQUAL, a cui viene accreditato il reward di 50 btc verso l'address P2SH. 

L'address P2SH effettuerà un'altra transazione firmando la transazione "manualmente" correggendo il parametro `s` della firma se otteniamo l'errore.
`non-mandatory-script-verify-flag (Non-canonical signature: S value is unnecessarily high) (code 64)` e aggiunto OP_3 per validare il custom script


[corsobitcoin.com](https://www.corsobitcoin.com)

--
# Setup the enviroment

TODO

[corsobitcoin.com](https://www.corsobitcoin.com)





