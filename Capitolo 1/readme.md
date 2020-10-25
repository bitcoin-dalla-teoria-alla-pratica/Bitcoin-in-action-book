# Replicare la transaction malleability.

Per prima cosa dobbiamo avere Bitcoin daemon nel nostro `$PATH` cosi da poterlo eseguire senza inserire il percorso. Se trovi difficoltà ricorda che il primo capitolo del libro o la wiki ufficiale di Bitcoin possono esserti utili

### Cambia la variabile ABSOLUTE_PATH.

Apri il file `tx.mall` e cambia il percorso `/Users/barno/Documents/bizantino/Bitcoin` con il tuo. Il path contiene la cartella della regtest. Puoi trovare il path di default a questo [indirizzo](https://en.bitcoin.it/wiki/Data_directory). Il path cambia in base al sistema operativo.

### Eseguire lo script
Eseguire lo script è molto semplice, base utilizzare il comando
`sh tx_mall.sh`.

--


# Setup enviroment

You must have **Bitcoin daemon** in your `$PATH` in order to be able to execute bitcoind without path. For more information you can check the first chapter or the official Bitcoin wiki.

### Change ABSOLUTE_PATH variable
Open the file `tx_mall.sh` and change the path `/Users/barno/Documents/bizantino/Bitcoin` with yours. That path contains the regtest folder. 
You can find the default path in that [link](https://en.bitcoin.it/wiki/Data_directory). It's depends on your operating system.

### Execute the script
It's very easy, execute the sh with that command:
`sh tx_mall.sh`.

[corsobitcoin.com](https://www.corsobitcoin.com)