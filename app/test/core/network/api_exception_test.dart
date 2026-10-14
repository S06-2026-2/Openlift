// FE-01 — ApiException: toda falha vira mensagem humana, nunca stack trace.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlift/core/network/api_exception.dart';

DioException _bad(int status, {Object? body}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  test('sem conexão vira mensagem de conexão', () {
    final e = ApiException.fromDio(DioException.connectionError(
      requestOptions: RequestOptions(path: '/x'),
      reason: 'SocketException: Failed host lookup',
    ));

    expect(e.message, contains('conectar ao servidor'));
    expect(e.message, isNot(contains('Socket')));
    expect(e.statusCode, isNull);
  });

  test('timeout vira mensagem de conexão', () {
    final e = ApiException.fromDio(DioException.connectionTimeout(
      timeout: const Duration(seconds: 10),
      requestOptions: RequestOptions(path: '/x'),
    ));

    expect(e.message, contains('conectar ao servidor'));
  });

  test('5xx vira "servidor com problemas", sem vazar o corpo', () {
    final e = ApiException.fromDio(
      _bad(500, body: {'detail': 'Traceback (most recent call last)...'}),
    );

    expect(e.message, contains('servidor está com problemas'));
    expect(e.message, isNot(contains('Traceback')));
    expect(e.statusCode, 500);
  });

  test('422 vira mensagem de dados inválidos', () {
    final e = ApiException.fromDio(_bad(422, body: {'detail': []}));

    expect(e.message, contains('dados são inválidos'));
  });

  test('overrides por status têm prioridade (401 no login)', () {
    final e = ApiException.fromDio(
      _bad(401),
      overrides: const {401: 'E-mail ou senha incorretos.'},
    );

    expect(e.message, 'E-mail ou senha incorretos.');
  });

  test('toString devolve só a mensagem', () {
    expect(const ApiException('oi').toString(), 'oi');
  });
}
