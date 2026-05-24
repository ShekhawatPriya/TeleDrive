class TelegramClientException implements Exception {
  const TelegramClientException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

class TelegramClientUnavailableException extends TelegramClientException {
  const TelegramClientUnavailableException(super.message, {super.code});
}

class TelegramAccountMismatchException extends TelegramClientException {
  const TelegramAccountMismatchException(super.message, {super.code});
}
