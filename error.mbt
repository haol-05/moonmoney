// Every failure a money operation can report.
//
// The variants are values, not messages: a caller can branch on
// `MoneyError::CurrencyMismatch` without matching on text, and
// `MoneyError::message` is there for the cases that only need to print.

///|
pub(all) suberror MoneyError {
  /// A divisor was zero.
  DivisionByZero
  /// An exact result did not fit an `Int64`; the payload names the operation.
  Overflow(String)
  /// Two amounts in different currencies were combined.
  CurrencyMismatch(String, String)
  /// No currency matched the code or symbol in the input.
  UnknownCurrency(String)
  /// A token matched more than one currency; the payload lists the codes.
  AmbiguousCurrency(String, String)
  /// Text could not be read as an amount; the payload says why.
  InvalidAmount(String, String)
  /// An allocation was asked for no parts, or given no weights.
  EmptyAllocation(String)
  /// An allocation was given weights that add up to zero.
  EmptyRatio
} derive(@debug.Debug)

///|
pub extend MoneyError with @debug.Debug::{to_repr}

///|
/// A printable explanation, used by the command line and by tests.
pub fn MoneyError::message(self : MoneyError) -> String {
  match self {
    DivisionByZero => "division by zero"
    Overflow(operation) => "the result of \{operation} does not fit in 64 bits"
    CurrencyMismatch(left, right) => "cannot combine \{left} with \{right}"
    UnknownCurrency(token) => "no currency matches \{token}"
    AmbiguousCurrency(token, candidates) =>
      "\{token} matches several currencies: \{candidates}"
    InvalidAmount(text, reason) => "cannot read \{text} as an amount: \{reason}"
    EmptyAllocation(what) => "\{what} needs at least one part"
    EmptyRatio => "the allocation weights add up to zero"
  }
}
