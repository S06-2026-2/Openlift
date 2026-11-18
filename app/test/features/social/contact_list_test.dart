// NOSTR-04 — ContactList: serialização do kind 3 (NIP-02) e parse da lista.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nostr_event.dart';
import 'package:openlift/core/nostr/nostr_kinds.dart';
import 'package:openlift/core/nostr/nostr_signer.dart';
import 'package:openlift/features/social/domain/contact_list.dart';

final _me = NostrSigner.generate(random: Random(1));
final _ana = NostrSigner.generate(random: Random(2)).publicKey;
final _bia = NostrSigner.generate(random: Random(3)).publicKey;
final _caio = NostrSigner.generate(random: Random(4)).publicKey;

NostrEvent _kind3(
  List<List<String>> tags, {
  int createdAt = 1000,
  String content = '',
  NostrSigner? signer,
}) {
  final by = signer ?? _me;
  return by.sign(UnsignedNostrEvent(
    pubkey: by.publicKey,
    createdAt: createdAt,
    kind: NostrKinds.contacts,
    tags: tags,
    content: content,
  ));
}

void main() {
  group('serialização', () {
    test('a lista vira um kind 3 assinável com uma tag p por pessoa', () {
      final list = const ContactList().follow(_ana).follow(_bia);

      final event = _me.sign(list.toUnsignedEvent(
        pubkey: _me.publicKey,
        now: 2000,
      ));

      expect(event.kind, NostrKinds.contacts);
      expect(event.kind, 3);
      expect(event.tags, [
        ['p', _ana],
        ['p', _bia],
      ]);
      expect(event.content, '');
      expect(event.createdAt, 2000);
      expect(event.isValid, isTrue);
    });

    test('seguir e deixar de seguir publicam a lista completa, não o delta',
        () {
      final before = const ContactList().follow(_ana).follow(_bia);

      final followed = before.follow(_caio);
      final unfollowed = followed.unfollow(_ana);

      expect(followed.pubkeys, [_ana, _bia, _caio]);
      expect(unfollowed.pubkeys, [_bia, _caio]);
      expect(
        unfollowed.toUnsignedEvent(pubkey: _me.publicKey, now: 1).tags,
        [
          ['p', _bia],
          ['p', _caio],
        ],
      );
    });

    test('mantém relay, apelido e content vindos de outro cliente', () {
      final list = ContactList.fromEvent(_kind3(
        [
          ['p', _ana, 'wss://relay.ana.test', 'ana'],
        ],
        content: '{"wss://relay.um.test":{"read":true,"write":true}}',
      ));

      final next = list.follow(_bia).toUnsignedEvent(
            pubkey: _me.publicKey,
            now: 2000,
          );

      expect(next.tags, [
        ['p', _ana, 'wss://relay.ana.test', 'ana'],
        ['p', _bia],
      ]);
      expect(
          next.content, '{"wss://relay.um.test":{"read":true,"write":true}}');
    });

    test('o created_at sempre passa o da versão atual, mesmo no mesmo segundo',
        () {
      final list = ContactList.fromEvent(_kind3([], createdAt: 5000));

      expect(
        list.toUnsignedEvent(pubkey: _me.publicKey, now: 5000).createdAt,
        5001,
      );
      expect(
        list.toUnsignedEvent(pubkey: _me.publicKey, now: 4000).createdAt,
        5001,
      );
      expect(
        list.toUnsignedEvent(pubkey: _me.publicKey, now: 6000).createdAt,
        6000,
      );
    });

    test('seguir quem já está ou deixar quem não está não muda a lista', () {
      final list = const ContactList().follow(_ana);

      expect(identical(list.follow(_ana), list), isTrue);
      expect(identical(list.unfollow(_bia), list), isTrue);
    });

    test('pubkey fora do formato hex é recusada', () {
      expect(
        () => const ContactList().follow('npub1naoehhex'),
        throwsArgumentError,
      );
    });
  });

  group('parse', () {
    test('lê as pubkeys das tags p, na ordem', () {
      final list = ContactList.fromEvent(_kind3([
        ['p', _ana],
        ['p', _bia, ''],
      ]));

      expect(list.pubkeys, [_ana, _bia]);
      expect(list.contains(_bia), isTrue);
      expect(list.contains(_caio), isFalse);
    });

    test('ignora tag p malformada, repetida e tags de outro tipo', () {
      final list = ContactList.fromEvent(_kind3([
        ['p'],
        ['p', 'nao-e-hex'],
        ['p', _ana.toUpperCase()],
        ['p', _ana],
        ['p', _ana, 'wss://repetida.test'],
        ['t', 'treino'],
        ['p', _bia],
      ]));

      expect(list.pubkeys, [_ana, _bia]);
    });

    test('evento de outro kind não é contact list', () {
      final event = _me.sign(UnsignedNostrEvent(
        pubkey: _me.publicKey,
        createdAt: 1,
        kind: NostrKinds.workoutRecord,
        tags: const [],
        content: '',
      ));

      expect(() => ContactList.fromEvent(event), throwsArgumentError);
    });
  });

  group('latest', () {
    test('fica com o kind 3 mais recente da pubkey (NIP-02 substituível)', () {
      final events = [
        _kind3([
          ['p', _ana],
        ], createdAt: 1000),
        _kind3([
          ['p', _ana],
          ['p', _bia],
        ], createdAt: 3000),
        _kind3([
          ['p', _caio],
        ], createdAt: 2000),
      ];

      final list = ContactList.latest(events, _me.publicKey);

      expect(list.pubkeys, [_ana, _bia]);
      expect(list.createdAt, 3000);
    });

    test('ignora evento adulterado, de outro autor e de outro kind', () {
      final valid = _kind3([
        ['p', _ana],
      ], createdAt: 1000);
      final newer = _kind3([
        ['p', _bia],
      ], createdAt: 5000);
      final tampered = NostrEvent(
        id: newer.id,
        pubkey: newer.pubkey,
        createdAt: newer.createdAt,
        kind: newer.kind,
        tags: [
          ['p', _caio],
        ],
        content: newer.content,
        sig: newer.sig,
      );
      final otherAuthor = _kind3([
        ['p', _caio],
      ], createdAt: 9000, signer: NostrSigner.generate(random: Random(9)));

      final list =
          ContactList.latest([valid, tampered, otherAuthor], _me.publicKey);

      expect(list.pubkeys, [_ana]);
    });

    test('empate de created_at fica com o menor id (NIP-01)', () {
      final a = _kind3([
        ['p', _ana],
      ], createdAt: 1000);
      final b = _kind3([
        ['p', _bia],
      ], createdAt: 1000);
      final expected = a.id.compareTo(b.id) < 0 ? _ana : _bia;

      expect(ContactList.latest([a, b], _me.publicKey).pubkeys, [expected]);
      expect(ContactList.latest([b, a], _me.publicKey).pubkeys, [expected]);
    });

    test('sem nenhum kind 3, a lista é vazia', () {
      final list = ContactList.latest(const [], _me.publicKey);

      expect(list.isEmpty, isTrue);
      expect(list.createdAt, 0);
    });
  });
}
