// FE-01 — Erro de API já traduzido para mensagem humana.
//
// Regra do projeto: o usuário nunca vê stack trace, JSON cru nem texto em
// inglês vindo do servidor. Toda falha de rede vira uma `ApiException` com
// uma frase que diz o que houve e o que fazer.

import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// Mensagem pronta para exibir na tela.
  final String message;

  /// Status HTTP, quando a falha veio de uma resposta do servidor.
  final int? statusCode;

  /// Traduz um [DioException].
  ///
  /// [overrides] troca a mensagem de status específicos para o contexto da
  /// chamada (ex.: no login, 401 significa "credenciais inválidas"; em
  /// qualquer outra rota significa "sessão expirada").
  factory ApiException.fromDio(
    DioException error, {
    Map<int, String> overrides = const {},
  }) {
    final type = error.type;
    if (type == DioExceptionType.cancel) {
      return const ApiException('A operação foi cancelada.');
    }
    if (type == DioExceptionType.badCertificate) {
      return const ApiException(
        'Não foi possível validar a conexão segura com o servidor.',
      );
    }
    // Sem resposta do servidor (timeout, offline, DNS...) = problema de conexão.
    if (error.response == null && type != DioExceptionType.unknown) {
      return const ApiException(
        'Não foi possível conectar ao servidor. '
        'Verifique sua conexão e tente novamente.',
      );
    }

    final status = error.response?.statusCode;
    if (status == null) {
      return const ApiException('Algo deu errado. Tente novamente.');
    }
    final override = overrides[status];
    if (override != null) return ApiException(override, statusCode: status);
    return ApiException(_messageFor(status), statusCode: status);
  }

  static String _messageFor(int status) {
    if (status >= 500) {
      return 'O servidor está com problemas. Tente novamente em instantes.';
    }
    switch (status) {
      case 400:
        return 'Não foi possível processar a solicitação. Confira os dados.';
      case 401:
        return 'Sua sessão expirou. Entre novamente.';
      case 403:
        return 'Você não tem permissão para fazer isso.';
      case 404:
        return 'Não encontramos o que você procurava.';
      case 409:
        return 'Esse registro já existe.';
      case 422:
        return 'Alguns dados são inválidos. Confira os campos e tente novamente.';
      case 429:
        return 'Muitas tentativas seguidas. Aguarde um instante e tente de novo.';
      default:
        return 'Algo deu errado. Tente novamente.';
    }
  }

  @override
  String toString() => message;
}
