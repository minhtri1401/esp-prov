/// Status codes a protocomm device returns (constants.proto `Status`).
enum ProvStatus {
  /// `Success = 0`.
  success,

  /// `InvalidSecScheme = 1`.
  invalidSecScheme,

  /// `InvalidProto = 2`.
  invalidProto,

  /// `TooManySessions = 3`.
  tooManySessions,

  /// `InvalidArgument = 4`.
  invalidArgument,

  /// `InternalError = 5`.
  internalError,

  /// `CryptoError = 6`.
  cryptoError,

  /// `InvalidSession = 7`.
  invalidSession,

  /// A value this library does not know about.
  unknown;

  /// Maps the wire value of constants.proto `Status` to a [ProvStatus].
  static ProvStatus fromValue(int value) =>
      value >= 0 && value < unknown.index ? values[value] : unknown;
}
