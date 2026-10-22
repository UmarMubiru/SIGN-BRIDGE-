/// Cloud authentication is excluded unless a build explicitly opts in.
///
/// Team builds that are intended to work fully offline should leave this
/// compile-time flag unset.
const cloudAuthEnabled = bool.fromEnvironment(
  'SIGNBRIDGE_ENABLE_CLOUD_AUTH',
  defaultValue: false,
);
