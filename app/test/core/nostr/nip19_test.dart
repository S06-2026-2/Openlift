// FE-04 — NIP-19 (npub/nsec em bech32). Vetores oficiais da NIP-19,
// conferidos também contra o `app/core/nostr.py` do backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nip19.dart';

const _pubHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
const _npub = 'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
const _secHex =
    '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';
const _nsec = 'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

void main() {
  group('vetores da NIP-19', () {
    test('npub: hex → bech32 → hex', () {
      expect(Nip19.encodeNpub(_pubHex), _npub);
      expect(Nip19.decodeNpub(_npub), _pubHex);
    });

    test('nsec: hex → bech32 → hex', () {
      expect(Nip19.encodeNsec(_secHex), _nsec);
      expect(Nip19.decodeNsec(_nsec), _secHex);
    });

    test('aceita espaços nas pontas e tudo em maiúsculas', () {
      expect(Nip19.decodeNsec('  $_nsec \n'), _secHex);
      expect(Nip19.decodeNpub(_npub.toUpperCase()), _pubHex);
    });
  });

  group('entrada inválida', () {
    test('prefixo trocado é recusado (npub não serve como nsec)', () {
      expect(() => Nip19.decodeNsec(_npub), throwsFormatException);
      expect(() => Nip19.decodeNpub(_nsec), throwsFormatException);
    });

    test('checksum errado, caractere fora do alfabeto e maiúscula misturada',
        () {
      final wrongChecksum = '${_nsec.substring(0, _nsec.length - 1)}x';
      expect(Nip19.decodeNsecOrNull(wrongChecksum), isNull);
      expect(Nip19.decodeNsecOrNull('nsec1bbbbbbbbbb'), isNull);
      expect(Nip19.decodeNsecOrNull('Nsec1${_nsec.substring(5)}'), isNull);
      expect(Nip19.decodeNsecOrNull(''), isNull);
    });

    test('a mensagem de erro nunca repete a chave recebida (RNF-01)', () {
      final almost = '${_nsec.substring(0, _nsec.length - 1)}q';
      try {
        Nip19.decodeNsec(almost);
        fail('deveria recusar');
      } on FormatException catch (e) {
        expect(e.toString(), isNot(contains(almost)));
        expect(e.toString(), isNot(contains(_secHex)));
      }
    });

    test('hex fora do formato não vira npub', () {
      expect(() => Nip19.encodeNpub('abc'), throwsFormatException);
      expect(() => Nip19.encodeNpub('z' * 64), throwsFormatException);
    });
  });
}
