import 'dart:io';

enum UpdateIssue {
  invalidVersion,
  invalidUrl,
  rateLimited,
  packageUnavailable,
  invalidMetadata,
  downloadSizeMismatch,
  checksumMismatch,
  unsafePath,
  linksUnsupported,
  invalidPackage,
  tooManyFiles,
  packageTooLarge,
  versionMismatch,
  missingRuntime,
  invalidInstallation,
  recoveryRequired,
  invalidJournal,
  updateBusy,
  closeListener,
  cancelled,
  network,
  fileSystem,
  unexpected,
}

final class UpdateFailure extends FormatException {
  const UpdateFailure(this.issue) : super('Update validation failed');
  final UpdateIssue issue;
}

final class UpdateFileFailure extends FileSystemException {
  const UpdateFileFailure(this.issue) : super('Update file operation failed');
  final UpdateIssue issue;
}
