// class StorageError extends Error {
class StorageException implements Exception {
  final String message;
  final causedBy;
  StorageException([this.message, this.causedBy]);
}
