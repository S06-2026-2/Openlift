// FE-04 — NIP-19: chaves em bech32 (BIP-173), o formato legível de chave.
//
//   npub1… = chave pública (pode ser mostrada e enviada ao backend)
//   nsec1… = chave PRIVADA (nunca sai do dispositivo — RNF-01, ADR-0006)
//
// As mensagens de erro nunca repetem o valor recebido: se alguém colar um
// nsec errado, ele não vai parar numa mensagem de erro nem num log.

abstract final class Nip19 {
  static const String npubPrefix = 'npub';
  static const String nsecPrefix = 'nsec';

  static const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  static const List<int> _generator = [
    0x3b6a57b2,
    0x26508e6d,
    0x1ea119fa,
    0x3d4233dd,
    0x2a1462b3,
  ];
  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Chave pública x-only (hex, 64 caracteres) → `npub1…`.
  static String encodeNpub(String publicKeyHex) =>
      _encodeKey(npubPrefix, publicKeyHex);

  /// Chave privada (hex, 64 caracteres) → `nsec1…`.
  static String encodeNsec(String secretKeyHex) =>
      _encodeKey(nsecPrefix, secretKeyHex);

  /// `npub1…` → chave pública em hex. Lança [FormatException].
  static String decodeNpub(String npub) => _decodeKey(npubPrefix, npub);

  /// `nsec1…` → chave privada em hex. Lança [FormatException] sem repetir a
  /// entrada na mensagem.
  static String decodeNsec(String nsec) => _decodeKey(nsecPrefix, nsec);

  /// Como [decodeNsec], mas devolve `null` em vez de lançar.
  static String? decodeNsecOrNull(String nsec) {
    try {
      return decodeNsec(nsec);
    } on FormatException {
      return null;
    }
  }

  static String _encodeKey(String prefix, String hex) {
    final normalized = hex.toLowerCase();
    if (!_hex64.hasMatch(normalized)) {
      throw const FormatException('Chave em hex inválida');
    }
    final bytes = [
      for (var i = 0; i < 64; i += 2)
        int.parse(normalized.substring(i, i + 2), radix: 16),
    ];
    final data = _convertBits(bytes, 8, 5, pad: true);
    final checksum = _createChecksum(prefix, data);
    return '${prefix}1${[...data, ...checksum].map((d) => _charset[d]).join()}';
  }

  static String _decodeKey(String prefix, String value) {
    final text = value.trim();
    if (text != text.toLowerCase() && text != text.toUpperCase()) {
      throw FormatException('Formato $prefix inválido');
    }
    final lower = text.toLowerCase();
    final separator = lower.lastIndexOf('1');
    if (separator < 1 || lower.substring(0, separator) != prefix) {
      throw FormatException('Formato $prefix inválido');
    }
    final data = <int>[];
    for (final char in lower.substring(separator + 1).split('')) {
      final index = _charset.indexOf(char);
      if (index < 0) throw FormatException('Formato $prefix inválido');
      data.add(index);
    }
    if (data.length < 6 || !_verifyChecksum(prefix, data)) {
      throw FormatException('Formato $prefix inválido');
    }
    final bytes =
        _convertBits(data.sublist(0, data.length - 6), 5, 8, pad: false);
    if (bytes.length != 32) throw FormatException('Formato $prefix inválido');
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static int _polymod(List<int> values) {
    var checksum = 1;
    for (final value in values) {
      final top = checksum >> 25;
      checksum = ((checksum & 0x1ffffff) << 5) ^ value;
      for (var i = 0; i < 5; i++) {
        if ((top >> i) & 1 == 1) checksum ^= _generator[i];
      }
    }
    return checksum;
  }

  static List<int> _hrpExpand(String hrp) => [
        for (final unit in hrp.codeUnits) unit >> 5,
        0,
        for (final unit in hrp.codeUnits) unit & 31,
      ];

  static List<int> _createChecksum(String hrp, List<int> data) {
    final polymod =
        _polymod([..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0]) ^ 1;
    return [for (var i = 0; i < 6; i++) (polymod >> (5 * (5 - i))) & 31];
  }

  static bool _verifyChecksum(String hrp, List<int> data) =>
      _polymod([..._hrpExpand(hrp), ...data]) == 1;

  static List<int> _convertBits(
    List<int> data,
    int fromBits,
    int toBits, {
    required bool pad,
  }) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxValue = (1 << toBits) - 1;
    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxValue);
      }
    }
    if (pad) {
      if (bits > 0) result.add((acc << (toBits - bits)) & maxValue);
    } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxValue) != 0) {
      throw const FormatException('Preenchimento inválido');
    }
    return result;
  }
}
