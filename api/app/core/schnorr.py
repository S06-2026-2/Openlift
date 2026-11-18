"""Verificação de assinatura Schnorr (BIP-340) sobre secp256k1, em Python puro.

Só **verifica**: o backend nunca assina evento nem conhece chave privada
(ADR-0006, RNF-01). A implementação segue a referência do BIP-340
(github.com/bitcoin/bips/blob/master/bip-0340/reference.py), em coordenadas
jacobianas para não pagar uma inversão modular por soma de pontos.

Sem dependência nativa (coincurve/secp256k1) de propósito: o volume da turma
é de centenas de eventos por ciclo, e uma verificação leva poucos
milissegundos, o que cabe com folga no RNF-06 (replay em < 5 min).
"""

import hashlib

# Parâmetros da curva secp256k1 (SEC 2, §2.4.1).
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)

# Ponto em coordenadas jacobianas (X, Y, Z), que representa (X/Z², Y/Z³).
# Z == 0 é o ponto no infinito.
_Jacobian = tuple[int, int, int]
_INFINITY: _Jacobian = (0, 1, 0)


def _to_jacobian(point: tuple[int, int]) -> _Jacobian:
    return (point[0], point[1], 1)


def _double(p1: _Jacobian) -> _Jacobian:
    x1, y1, z1 = p1
    if z1 == 0 or y1 == 0:
        return _INFINITY
    y1_sq = y1 * y1 % P
    s = 4 * x1 * y1_sq % P
    m = 3 * x1 * x1 % P  # a = 0 na secp256k1
    x3 = (m * m - 2 * s) % P
    y3 = (m * (s - x3) - 8 * y1_sq * y1_sq) % P
    z3 = 2 * y1 * z1 % P
    return (x3, y3, z3)


def _add(p1: _Jacobian, p2: _Jacobian) -> _Jacobian:
    x1, y1, z1 = p1
    x2, y2, z2 = p2
    if z1 == 0:
        return p2
    if z2 == 0:
        return p1
    z1_sq = z1 * z1 % P
    z2_sq = z2 * z2 % P
    u1 = x1 * z2_sq % P
    u2 = x2 * z1_sq % P
    s1 = y1 * z2_sq * z2 % P
    s2 = y2 * z1_sq * z1 % P
    if u1 == u2:
        return _double(p1) if s1 == s2 else _INFINITY
    h = (u2 - u1) % P
    r = (s2 - s1) % P
    h_sq = h * h % P
    h_cu = h_sq * h % P
    u1_h_sq = u1 * h_sq % P
    x3 = (r * r - h_cu - 2 * u1_h_sq) % P
    y3 = (r * (u1_h_sq - x3) - s1 * h_cu) % P
    z3 = h * z1 * z2 % P
    return (x3, y3, z3)


def _multiply(point: _Jacobian, scalar: int) -> _Jacobian:
    result = _INFINITY
    addend = point
    while scalar:
        if scalar & 1:
            result = _add(result, addend)
        addend = _double(addend)
        scalar >>= 1
    return result


def _to_affine(point: _Jacobian) -> tuple[int, int] | None:
    x, y, z = point
    if z == 0:
        return None
    z_inv = pow(z, -1, P)
    z_inv_sq = z_inv * z_inv % P
    return (x * z_inv_sq % P, y * z_inv_sq * z_inv % P)


def _lift_x(x: int) -> tuple[int, int] | None:
    """Ponto de coordenada x com y par (BIP-340), ou None se não existir."""
    if x >= P:
        return None
    y_sq = (pow(x, 3, P) + 7) % P
    y = pow(y_sq, (P + 1) // 4, P)
    if y * y % P != y_sq:
        return None
    return (x, y if y % 2 == 0 else P - y)


def _tagged_hash(tag: str, data: bytes) -> bytes:
    tag_hash = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(tag_hash + tag_hash + data).digest()


def verify(message: bytes, pubkey: bytes, signature: bytes) -> bool:
    """BIP-340: `signature` (64 bytes) de `message` (32 bytes) pela chave
    x-only `pubkey` (32 bytes). Nunca lança: entrada inválida é `False`."""
    if len(message) != 32 or len(pubkey) != 32 or len(signature) != 64:
        return False
    point = _lift_x(int.from_bytes(pubkey, "big"))
    if point is None:
        return False
    r = int.from_bytes(signature[:32], "big")
    s = int.from_bytes(signature[32:], "big")
    if r >= P or s >= N:
        return False
    e = int.from_bytes(_tagged_hash("BIP0340/challenge", signature[:32] + pubkey + message), "big")
    e %= N
    # R = s·G − e·P  (−e·P = (N − e)·P)
    combined = _add(_multiply(_to_jacobian(G), s), _multiply(_to_jacobian(point), N - e))
    affine = _to_affine(combined)
    if affine is None:
        return False
    return affine[1] % 2 == 0 and affine[0] == r
