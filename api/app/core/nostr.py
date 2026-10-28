"""NIP-19: conversão entre a chave pública em hex e o `npub` (bech32, BIP-173).

O backend só lida com chave PÚBLICA (ADR-0006). Não existe aqui, de propósito,
nada que leia ou produza `nsec`.
"""

_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
_GENERATOR = (0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3)
_NPUB_HRP = "npub"
_NPUB_LENGTH = 63  # "npub1" + 52 caracteres de dado + 6 de checksum

# Kinds do mini-NIP (docs/nips/openlift-workout-event.md §1), em constante única.
KIND_WORKOUT_RECORD = 1301


def _polymod(values: list[int]) -> int:
    checksum = 1
    for value in values:
        top = checksum >> 25
        checksum = (checksum & 0x1FFFFFF) << 5 ^ value
        for i, generator in enumerate(_GENERATOR):
            if (top >> i) & 1:
                checksum ^= generator
    return checksum


def _hrp_expand(hrp: str) -> list[int]:
    return [ord(c) >> 5 for c in hrp] + [0] + [ord(c) & 31 for c in hrp]


def _convert_bits(data: list[int], from_bits: int, to_bits: int, pad: bool) -> list[int]:
    acc = bits = 0
    result: list[int] = []
    max_value = (1 << to_bits) - 1
    for value in data:
        acc = (acc << from_bits) | value
        bits += from_bits
        while bits >= to_bits:
            bits -= to_bits
            result.append((acc >> bits) & max_value)
    if pad:
        if bits:
            result.append((acc << (to_bits - bits)) & max_value)
    elif bits >= from_bits or (acc << (to_bits - bits)) & max_value:
        raise ValueError("npub com preenchimento inválido")
    return result


def npub_to_hex(npub: str) -> str:
    """`npub1...` → chave pública x-only em hex. Lança ValueError se inválido."""
    if len(npub) != _NPUB_LENGTH or npub != npub.lower():
        raise ValueError("npub deve ter 63 caracteres minúsculos")
    hrp, separator, data_part = npub.rpartition("1")
    if hrp != _NPUB_HRP or not separator:
        raise ValueError("npub deve começar com 'npub1'")
    if any(c not in _CHARSET for c in data_part):
        raise ValueError("npub com caractere fora do alfabeto bech32")
    data = [_CHARSET.index(c) for c in data_part]
    if _polymod(_hrp_expand(hrp) + data) != 1:
        raise ValueError("npub com checksum inválido")
    key = _convert_bits(data[:-6], 5, 8, pad=False)
    if len(key) != 32:
        raise ValueError("npub deve conter 32 bytes")
    return bytes(key).hex()


def hex_to_npub(pubkey_hex: str) -> str:
    """Chave pública x-only em hex (64 caracteres) → `npub1...`."""
    key = bytes.fromhex(pubkey_hex)
    if len(key) != 32:
        raise ValueError("chave pública deve ter 32 bytes")
    data = _convert_bits(list(key), 8, 5, pad=True)
    polymod = _polymod(_hrp_expand(_NPUB_HRP) + data + [0] * 6) ^ 1
    checksum = [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]
    return _NPUB_HRP + "1" + "".join(_CHARSET[d] for d in data + checksum)
