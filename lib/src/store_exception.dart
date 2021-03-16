// class StorageError extends Error {
class StorageException implements Exception {
  final String message;
  final dynamic? causedBy;
  final StackTrace? stackTrace;
  StorageException(this.message, [this.causedBy, this.stackTrace]);
}
