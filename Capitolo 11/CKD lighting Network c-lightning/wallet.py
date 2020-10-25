import hashlib
import hmac
from math import ceil
from binascii import hexlify
import sys

if len(sys.argv) >= 2:
    hexdata=sys.argv[1]
else:
    with open('/tmp/l1-regtest/regtest/hsm_secret', 'rb') as f:
            hexdata = f.read().hex()

hsm_secret_as_hex = hexdata
hsm_secret = bytes.fromhex(hsm_secret_as_hex)

hash_len = 32
def hmac_sha256(key, data):
    return hmac.new(key, data, hashlib.sha256).digest()

def hkdf(length, ikm, salt=b"", info=b""):
    prk = hmac_sha256(salt, ikm)
    t = b""
    okm = b""
    for i in range(ceil(length / hash_len)):
        t = hmac_sha256(prk, t + info + bytes([1+i]))
        okm += t
    return okm[:length]

bip32_seed = hkdf(32, hsm_secret, b"\x00", b"bip32 seed")
print(hexlify(bip32_seed).decode('ascii'))


#channel_seed = hkdf(hkdf(hsm_secret, salt=NULL, info="peer seed"), salt=peer_id | dbid, info="per-peer seed")
#print(hexlify(channel_seed).decode('ascii'))

#[funding, revocation, payment, htlc, delayed, shaseed] = expanded_hkdf_sha256(channel_seed, salt=NULL, info="c-lightning")



#TODO non usare bx
#https://github.com/hkjn/lnhw/tree/master/doc/hsmd
#private_key_node = hkdf(32, hsm_secret, b"\x00", b"nodeid")
#print(hexlify(private_key_node).decode('ascii'))
#bx ec-to-public private_key_node => public key del nodo
