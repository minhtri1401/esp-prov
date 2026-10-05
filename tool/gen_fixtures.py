#!/usr/bin/env python3
# Generates byte-exact protocomm Security 1 / Security 2 fixtures by driving
# Espressif's own esp_prov Python modules against a simulated device that
# mirrors the firmware (components/protocomm/src/security/security1.c and
# components/protocomm/src/crypto/srp6a/esp_srp.c).
#
# Usage (from the repo root):
#   uv venv .venv && uv pip install --python .venv/bin/python -r tool/requirements.txt
#   .venv/bin/python tool/gen_fixtures.py
#
# Output: packages/esp_prov_core/test/fixtures/{sec1,sec2}*.json
import hashlib
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.cache' / 'espressif'
OUT = ROOT / 'packages' / 'esp_prov_core' / 'test' / 'fixtures'

# Keep in sync with third_party/espressif/proto/README.md.
IDF_URL = 'https://github.com/espressif/esp-idf.git'
IDF_COMMIT = '4d59230ddff16327812782151ef0afef202dc6d7'
IEC_URL = 'https://github.com/espressif/idf-extra-components.git'
IEC_COMMIT = '69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0'


def sparse_checkout(url: str, commit: str, dest: Path, paths: list) -> None:
    marker = dest / '.fixture-commit'
    if marker.exists() and marker.read_text().strip() == commit:
        return
    dest.mkdir(parents=True, exist_ok=True)

    def git(*args: str) -> None:
        subprocess.run(['git', '-C', str(dest), *args], check=True)

    if not (dest / '.git').exists():
        git('init', '-q')
        git('remote', 'add', 'origin', url)
    git('sparse-checkout', 'set', '--no-cone', *paths)
    git('fetch', '-q', '--depth', '1', '--filter=blob:none', 'origin', commit)
    git('checkout', '-q', 'FETCH_HEAD')
    marker.write_text(commit)


IDF_DIR = CACHE / 'esp-idf'
IEC_DIR = CACHE / 'idf-extra-components'
sparse_checkout(IDF_URL, IDF_COMMIT, IDF_DIR, ['/components/protocomm/python/'])
sparse_checkout(IEC_URL, IEC_COMMIT, IEC_DIR,
                ['/network_provisioning/tool/esp_prov/', '/network_provisioning/python/'])

# esp_prov's proto/__init__.py loads protocomm *_pb2.py from $IDF_PATH and the
# network_*_pb2.py files relative to the esp_prov directory.
os.environ['IDF_PATH'] = str(IDF_DIR)
sys.path.insert(0, str(IEC_DIR / 'network_provisioning' / 'tool' / 'esp_prov'))

import proto  # noqa: E402  (esp_prov/proto)
import security  # noqa: E402  (esp_prov/security)
from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.x25519 import (  # noqa: E402
    X25519PrivateKey, X25519PublicKey)
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes  # noqa: E402
from cryptography.hazmat.primitives.ciphers.aead import AESGCM  # noqa: E402

sec1_module = sys.modules['security.security1']
srp_module = sys.modules['security.srp6a']
session_pb2 = proto.session_pb2
sec1_pb2 = proto.sec1_pb2
sec2_pb2 = proto.sec2_pb2
constants_pb2 = proto.constants_pb2


def hx(data: bytes) -> str:
    return data.hex()


def raw_public(private_key: X25519PrivateKey) -> bytes:
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)


def minimal(n: int) -> bytes:
    # mbedtls / esp_mpi_to_bin: big-endian, no leading zero bytes.
    return b'\x00' if n == 0 else n.to_bytes((n.bit_length() + 7) // 8, 'big')


def sha512(*parts: bytes) -> bytes:
    h = hashlib.sha512()
    for p in parts:
        h.update(p)
    return h.digest()


# Plaintexts exchanged after the handshake. Lengths 1, 5, 16, 17, 40 and 3
# make the AES-CTR keystream offset cross block boundaries in both directions.
SAMPLES = [
    ('client_to_device', b'\x01'),
    ('device_to_client', b'hello'),
    ('client_to_device', bytes(range(16))),
    ('device_to_client', bytes(range(100, 117))),
    ('client_to_device', b'{"ssid":"MyNetwork","passphrase":"x"}' + b'\x00\x01\x02'),
    ('device_to_client', b'end'),
]


# ---------------------------------------------------------------- Security 1
def make_sec1(name: str, pop: str, client_priv: bytes, device_priv: bytes,
              device_random: bytes) -> dict:
    class _FixedClientKey:
        @staticmethod
        def generate() -> X25519PrivateKey:
            return X25519PrivateKey.from_private_bytes(client_priv)

    # Security1.__generate_key() calls X25519PrivateKey.generate(); swap the
    # module-level name so the client key pair is deterministic.
    sec1_module.X25519PrivateKey = _FixedClientKey

    dev_key = X25519PrivateKey.from_private_bytes(device_priv)
    dev_pub = raw_public(dev_key)

    client = security.Security1(pop, False)
    cmd0 = client.security1_session(None).encode('latin-1')
    parsed0 = session_pb2.SessionData()
    parsed0.ParseFromString(cmd0)
    client_pub = parsed0.sec1.sc0.client_pubkey

    shared = dev_key.exchange(X25519PublicKey.from_public_bytes(client_pub))
    if pop:
        digest = hashlib.sha256(pop.encode()).digest()
        shared = bytes(a ^ b for a, b in zip(shared, digest))
    device_ctr = Cipher(algorithms.AES(shared), modes.CTR(device_random)).encryptor()

    resp0 = session_pb2.SessionData()
    resp0.sec_ver = session_pb2.SecScheme1
    resp0.sec1.msg = sec1_pb2.Session_Response0
    resp0.sec1.sr0.status = constants_pb2.Success
    resp0.sec1.sr0.device_pubkey = dev_pub
    resp0.sec1.sr0.device_random = device_random
    resp0_bytes = resp0.SerializeToString()

    cmd1 = client.security1_session(resp0_bytes.decode('latin-1')).encode('latin-1')
    parsed1 = session_pb2.SessionData()
    parsed1.ParseFromString(cmd1)
    client_verify = parsed1.sec1.sc1.client_verify_data
    assert device_ctr.update(client_verify) == dev_pub, 'device rejected client verify'
    device_verify = device_ctr.update(client_pub)

    resp1 = session_pb2.SessionData()
    resp1.sec_ver = session_pb2.SecScheme1
    resp1.sec1.msg = sec1_pb2.Session_Response1
    resp1.sec1.sr1.status = constants_pb2.Success
    resp1.sec1.sr1.device_verify_data = device_verify
    resp1_bytes = resp1.SerializeToString()
    assert client.security1_session(resp1_bytes.decode('latin-1')) is None

    messages = []
    for direction, plain in SAMPLES:
        if direction == 'client_to_device':
            cipher = client.encrypt_data(plain)
            assert device_ctr.update(cipher) == plain
        else:
            cipher = device_ctr.update(plain)
            assert client.decrypt_data(cipher) == plain
        messages.append({'direction': direction, 'plain': hx(plain), 'cipher': hx(cipher)})

    return {
        'name': name,
        'pop': pop,
        'client_private_key': hx(client_priv),
        'client_public_key': hx(client_pub),
        'device_private_key': hx(device_priv),
        'device_public_key': hx(dev_pub),
        'device_random': hx(device_random),
        'session_key': hx(shared),
        'session_cmd0': hx(cmd0),
        'session_resp0': hx(resp0_bytes),
        'session_cmd1': hx(cmd1),
        'session_resp1': hx(resp1_bytes),
        'client_verify_data': hx(client_verify),
        'device_verify_data': hx(device_verify),
        'messages': messages,
    }


# ---------------------------------------------------------------- Security 2
N, G = srp_module.get_ng(srp_module.NG_3072)
N_LEN = 384

# Salt and verifier hard-coded in ESP-IDF v5.4.2
# examples/provisioning/wifi_prov_mgr/main/app_main.c for wifiprov / abcd1234.
EXAMPLE_SALT = bytes.fromhex('036ee0c7bcb9eda84c9eac97d93decf4')
EXAMPLE_VERIFIER = bytes.fromhex(
    '7c7c85476508946dd636af37d7e8914378cffd616c59d2f83908127238de9e24'
    'a470261cdfa903c2b270e7b13224da111d9718dc607208cc9ac90c4827e2ae89'
    'aa1625b804d21a9b3a8f37f6e43a712ee127866eadce28ff5446601fb99687dc'
    '5740a7d46cc97754dc1682f0ed356ac470ad3d90b5819470d7bc65b2d518e02e'
    'c3a5f968dd647bb8b73c9cfc00d8717eb79a7cb1b7c2c318342932433e0099e9'
    '8294e3d82ab09629b7df0e5f08334076529132009f972c896c391ec828054417'
    '3f68028a9f4461d1f5a17e5a70d2c72381cb3868e42c20bc40577617bd08b896'
    'bc26eb32466935058c1570d91be9becca938a667f0ad5013197264bf52c234e2'
    '1b11797472bd345bb1e2fd6673fe716474d04ebc51241940870e9240e621e72d'
    '4e37762f2ee268c789e8321342068484534ab30c1b4c8d1c519719abae77ffdb'
    'ecf0109534336bcb3e840fb9d85fb8a0b855533e70f718f5ce7b4ebf27cecea8'
    'b3be40c5c532293e71649ede8cf675a1e6f653c831a878de5040f762de36b2ba'
)


def fw_x(salt: bytes, username: str, password: str) -> int:
    # esp_srp.c calculate_x: SHA512(salt | SHA512(I ":" p)), full 64-byte inner digest.
    inner = sha512(username.encode(), b':', password.encode())
    return int.from_bytes(sha512(salt, inner), 'big')


def fw_padded_hash(a: bytes, b: bytes) -> int:
    pad = lambda v: bytes(N_LEN - len(v)) + v  # noqa: E731
    return int.from_bytes(sha512(pad(a), pad(b)), 'big')


FW_K = fw_padded_hash(minimal(N), minimal(G))


def fw_h_n_xor_h_g() -> bytes:
    hn = sha512(minimal(N))
    hg = sha512(bytes(N_LEN - 1) + minimal(G))
    return bytes(x ^ y for x, y in zip(hn, hg))


def make_sec2(name: str, username: str, password: str, salt: bytes, verifier: bytes,
              a: int, b: int, device_nonce: bytes, with_messages: bool) -> dict:
    v = int.from_bytes(verifier, 'big')
    assert pow(G, fw_x(salt, username, password), N) == v, 'verifier does not match firmware x'
    # Python esp_prov strips leading zero bytes when it converts digests to
    # ints; these fixtures must avoid inputs where it would differ from firmware.
    assert salt[0] != 0
    assert sha512(username.encode(), b':', password.encode())[0] != 0

    srp_module.get_random_of_length = lambda nbytes: a  # deterministic client 'a'

    client = security.Security2(1, username, password, False)
    cmd0 = client.security2_session(None).encode('latin-1')
    p0 = session_pb2.SessionData()
    p0.ParseFromString(cmd0)
    a_bytes = p0.sec2.sc0.client_pubkey
    assert len(a_bytes) == N_LEN, 'fixed a must give a 384-byte A'
    assert p0.sec2.sc0.client_username == username.encode()

    big_b = (FW_K * v + pow(G, b, N)) % N
    b_bytes = minimal(big_b)

    resp0 = session_pb2.SessionData()
    resp0.sec_ver = session_pb2.SecScheme2
    resp0.sec2.msg = sec2_pb2.S2Session_Response0
    resp0.sec2.sr0.status = constants_pb2.Success
    resp0.sec2.sr0.device_pubkey = b_bytes
    resp0.sec2.sr0.device_salt = salt
    resp0_bytes = resp0.SerializeToString()

    cmd1 = client.security2_session(resp0_bytes.decode('latin-1')).encode('latin-1')
    p1 = session_pb2.SessionData()
    p1.ParseFromString(cmd1)
    m1 = p1.sec2.sc1.client_proof

    # Device side, mirroring esp_srp_get_session_key / esp_srp_exchange_proofs.
    big_a = int.from_bytes(a_bytes, 'big')
    u = fw_padded_hash(a_bytes, b_bytes)
    big_s = pow(big_a * pow(v, u, N) % N, b, N)
    session_key = sha512(minimal(big_s))
    expected_m1 = sha512(fw_h_n_xor_h_g(), sha512(username.encode()), salt, a_bytes,
                         b_bytes, session_key)
    assert m1 == expected_m1, 'esp_prov M1 differs from firmware M1'
    m2 = sha512(a_bytes, m1, session_key)

    resp1 = session_pb2.SessionData()
    resp1.sec_ver = session_pb2.SecScheme2
    resp1.sec2.msg = sec2_pb2.S2Session_Response1
    resp1.sec2.sr1.status = constants_pb2.Success
    resp1.sec2.sr1.device_proof = m2
    resp1.sec2.sr1.device_nonce = device_nonce
    resp1_bytes = resp1.SerializeToString()
    assert client.security2_session(resp1_bytes.decode('latin-1')) is None
    assert client.srp6a_ctx.authenticated()

    result = {
        'name': name,
        'username': username,
        'password': password,
        'salt': hx(salt),
        'verifier': hx(verifier),
        'a': format(a, 'x'),
        'b': format(b, 'x'),
        'client_public_key': hx(a_bytes),
        'device_public_key': hx(b_bytes),
        'u': format(u, 'x'),
        'session_key': hx(session_key),
        'client_proof': hx(m1),
        'device_proof': hx(m2),
        'device_nonce': hx(device_nonce),
        'session_cmd0': hx(cmd0),
        'session_resp0': hx(resp0_bytes),
        'session_cmd1': hx(cmd1),
        'session_resp1': hx(resp1_bytes),
        'premaster_secret_length': len(minimal(big_s)),
    }
    if with_messages:
        for patch in (0, 1):
            client.sec_patch_ver = patch
            client.nonce = bytearray(device_nonce)
            device_gcm = AESGCM(session_key[:32])
            device_counter = bytearray(device_nonce)
            messages = []
            for direction, plain in SAMPLES:
                nonce_used = bytes(device_counter)
                if direction == 'client_to_device':
                    cipher = client.encrypt_data(plain)
                    assert device_gcm.decrypt(nonce_used, cipher, None) == plain
                else:
                    cipher = device_gcm.encrypt(nonce_used, plain, None)
                    assert client.decrypt_data(cipher) == plain
                if patch == 1:
                    counter = struct.unpack('>I', device_counter[8:])[0] + 1
                    device_counter[8:] = struct.pack('>I', counter)
                messages.append({'direction': direction, 'nonce': hx(nonce_used),
                                 'plain': hx(plain), 'cipher': hx(cipher)})
            result[f'messages_patch{patch}'] = messages
    return result


def find_b(a: int, salt: bytes, verifier: bytes, predicate, start: int) -> int:
    v = int.from_bytes(verifier, 'big')
    a_bytes = minimal(pow(G, a, N))
    b = start
    while True:
        big_b = (FW_K * v + pow(G, b, N)) % N
        u = fw_padded_hash(a_bytes, minimal(big_b))
        big_s = pow(pow(G, a, N) * pow(v, u, N) % N, b, N)
        if predicate(minimal(big_b), minimal(big_s)):
            return b
        b += 1


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fixtures = {
        'sec1_pop.json': make_sec1(
            'sec1 with PoP abcd1234', 'abcd1234',
            client_priv=bytes(range(1, 33)),
            device_priv=bytes(range(0x41, 0x61)),
            device_random=bytes.fromhex('0f1e2d3c4b5a69788796a5b4c3d2e1f0')),
        'sec1_no_pop_carry.json': make_sec1(
            'sec1 without PoP, IV low 64 bits at 0xff..fe (counter carry)', '',
            client_priv=bytes(range(0x80, 0xa0)),
            device_priv=bytes(range(0xc0, 0xe0)),
            device_random=bytes.fromhex('0123456789abcdeffffffffffffffffe')),
    }

    a = (1 << 255) | int.from_bytes(sha512(b'esp_prov fixture a')[:32], 'big')
    b = int.from_bytes(sha512(b'esp_prov fixture b')[:32], 'big')
    nonce = bytes.fromhex('a1b2c3d4e5f60718') + struct.pack('>I', 1)
    fixtures['sec2_example.json'] = make_sec2(
        'sec2 wifiprov/abcd1234 with the wifi_prov_mgr example salt and verifier',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, b, nonce, True)

    short_b = find_b(a, EXAMPLE_SALT, EXAMPLE_VERIFIER,
                     lambda bb, ss: len(bb) < N_LEN, start=b + 1)
    fixtures['sec2_short_b.json'] = make_sec2(
        'sec2 where the device public key B serialises to fewer than 384 bytes',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, short_b, nonce, False)

    short_s = find_b(a, EXAMPLE_SALT, EXAMPLE_VERIFIER,
                     lambda bb, ss: len(bb) == N_LEN and len(ss) < N_LEN, start=b + 1)
    fixtures['sec2_short_s.json'] = make_sec2(
        'sec2 where the premaster secret S has a leading zero byte (K = H(S) unpadded)',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, short_s, nonce, False)

    for file_name, data in fixtures.items():
        data['generator'] = {'esp_idf': IDF_COMMIT, 'idf_extra_components': IEC_COMMIT}
        (OUT / file_name).write_text(json.dumps(data, indent=2) + '\n')
        print(f'wrote {OUT / file_name}')


if __name__ == '__main__':
    main()
