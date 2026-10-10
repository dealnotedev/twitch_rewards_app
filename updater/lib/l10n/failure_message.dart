import '../core/update_failure.dart';
import 'generated/updater_localizations.dart';

String failureMessage(UpdaterLocalizations strings, UpdateIssue issue) =>
    switch (issue) {
      UpdateIssue.invalidVersion => strings.invalidVersion,
      UpdateIssue.invalidUrl => strings.invalidUrl,
      UpdateIssue.rateLimited => strings.rateLimited,
      UpdateIssue.packageUnavailable => strings.packageUnavailable,
      UpdateIssue.invalidMetadata => strings.invalidMetadata,
      UpdateIssue.downloadSizeMismatch => strings.downloadSizeMismatch,
      UpdateIssue.checksumMismatch => strings.checksumMismatch,
      UpdateIssue.unsafePath => strings.unsafePath,
      UpdateIssue.linksUnsupported => strings.linksUnsupported,
      UpdateIssue.invalidPackage => strings.invalidPackage,
      UpdateIssue.tooManyFiles => strings.tooManyFiles,
      UpdateIssue.packageTooLarge => strings.packageTooLarge,
      UpdateIssue.versionMismatch => strings.versionMismatch,
      UpdateIssue.missingRuntime => strings.missingRuntime,
      UpdateIssue.invalidInstallation => strings.invalidInstallation,
      UpdateIssue.recoveryRequired => strings.recoveryRequired,
      UpdateIssue.invalidJournal => strings.invalidJournal,
      UpdateIssue.updateBusy => strings.updateBusy,
      UpdateIssue.closeListener => strings.closeListener,
      UpdateIssue.cancelled => strings.cancelled,
      UpdateIssue.network => strings.networkError,
      UpdateIssue.fileSystem => strings.fileError,
      UpdateIssue.unexpected => strings.unexpectedError,
    };
