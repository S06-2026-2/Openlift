// FE-04 — NostrIdentityService: gera uma vez, reutiliza, separa por conta,
// importa nsec (RF-04) e nunca expõe a chave privada.

import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/nostr/nip19.dart';
import 'package:openlift/core/storage/secure_storage_service.dart';
import 'package:openlift/features/auth/data/nostr_identity_service.dart';

import '../../helpers/fake_http_adapter.dart';

const _nsec = 'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _secHex =
    '67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa';

void main() {
  late MemorySecureStorage storage;
  late NostrIdentityService service;

  setUp(() {
    storage = MemorySecureStorage();
    service = NostrIdentityService(storage: storage);
  });

  test('1º uso gera e guarda a chave; os seguintes reutilizam a mesma',
      () async {
    final first = await service.ensureIdentity(1);
    final again = await service.ensureIdentity(1);
    // Um serviço novo (app reaberto) lê do armazenamento.
    final reopened =
        await NostrIdentityService(storage: storage).ensureIdentity(1);

    expect(first.npub, startsWith('npub1'));
    expect(Nip19.decodeNpub(first.npub), first.publicKeyHex);
    expect(again, first);
    expect(reopened, first);
    expect(await storage.readNostrSecret(1), hasLength(64));
  });

  test('cada conta no mesmo aparelho tem a sua identidade', () async {
    final a = await service.ensureIdentity(1);
    final b = await service.ensureIdentity(2);

    expect(a, isNot(b));
    expect(await storage.readNostrSecret(1),
        isNot(await storage.readNostrSecret(2)));
  });

  test('o logout não apaga a identidade', () async {
    final before = await service.ensureIdentity(1);
    await storage.saveSessionTokens(accessToken: 'acc', refreshToken: 'ref');

    await storage.clearSession();

    expect(await storage.readAccessToken(), isNull);
    expect(await service.ensureIdentity(1), before);
  });

  test('valor corrompido no armazenamento gera identidade nova', () async {
    await storage.saveNostrSecret(1, 'lixo');

    final identity = await service.ensureIdentity(1);

    expect(identity.npub, startsWith('npub1'));
    expect(await storage.readNostrSecret(1), isNot('lixo'));
  });

  test('a parte pública nunca carrega a chave privada', () async {
    final identity = await service.ensureIdentity(1);
    final secret = (await storage.readNostrSecret(1))!;
    final signer = await service.signerFor(1);

    expect(identity.toString(), isNot(contains(secret)));
    expect(identity.toString(), isNot(contains('nsec')));
    expect(signer.toString(), isNot(contains(secret)));
  });

  group('importação de nsec (RF-04)', () {
    test('nsec válido substitui a identidade da conta', () async {
      await service.ensureIdentity(1);

      final imported = await service.importNsec(1, _nsec);

      expect(await storage.readNostrSecret(1), _secHex);
      expect(await service.ensureIdentity(1), imported);
      expect(service.previewNsec(_nsec), imported);
    });

    test('nsec inválido é recusado sem tocar na identidade atual', () async {
      final current = await service.ensureIdentity(1);
      final secret = await storage.readNostrSecret(1);

      await expectLater(
        service.importNsec(1, 'nsec1invalido'),
        throwsA(isA<InvalidNsecException>()),
      );
      expect(() => service.previewNsec(_nsec.replaceFirst('nsec', 'npub')),
          throwsA(isA<InvalidNsecException>()));
      expect(await storage.readNostrSecret(1), secret);
      expect(await service.ensureIdentity(1), current);
    });

    test('a mensagem de erro não repete o que foi colado', () {
      const pasted =
          'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfeX';
      try {
        service.previewNsec(pasted);
        fail('deveria recusar');
      } on InvalidNsecException catch (e) {
        expect(e.toString(), isNot(contains(pasted)));
      }
    });
  });

  test('a chave fica sob uma chave de armazenamento própria por conta', () {
    expect(SecureStorageService.nostrSecretKey(7), 'nostr.secret.7');
  });
}
