import 'update_failure.dart';

final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.build = 0]);

  factory AppVersion.parse(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
        .firstMatch(value.trim());
    if (match == null) throw const UpdateFailure(UpdateIssue.invalidVersion);
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      int.parse(match[4] ?? '0'),
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int build;

  bool matchesRelease(AppVersion tag) =>
      major == tag.major &&
      minor == tag.minor &&
      patch == tag.patch &&
      (tag.build == 0 || build == tag.build);

  @override
  int compareTo(AppVersion other) {
    final a = [major, minor, patch, build];
    final b = [other.major, other.minor, other.patch, other.build];
    for (var i = 0; i < a.length; i++) {
      final difference = a[i].compareTo(b[i]);
      if (difference != 0) return difference;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;
  @override
  int get hashCode => Object.hash(major, minor, patch, build);
  @override
  String toString() => '$major.$minor.$patch${build > 0 ? '+$build' : ''}';
}
