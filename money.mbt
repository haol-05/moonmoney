// The Money type: an exact amount in the minor units of one currency.
//
// `minor` is the amount in the smallest unit the currency defines -- cents for
// USD, yen for JPY, fils for BHD -- so 12.34 USD is `{ minor: 1234 }`. Nothing
// in this file uses a floating point number: the amount is always an integer,
// and every operation that would leave the integers goes through an explicit
// rounding mode.

///|
/// An amount of money: an integer number of minor units plus its currency.
pub(all) struct Money {
  minor : Int64
  currency : Currency
} derive(Debug)

///|
pub extend Money with @debug.Debug::{to_repr}

///|
/// Amounts are equal when they are the same number of minor units of the same
/// currency. The rest of the currency record -- name, symbol, cash rules -- is
/// display data and does not take part in the comparison.
pub impl Eq for Money with fn equal(self, other) {
  self.minor == other.minor && self.currency.code == other.currency.code
}

///|
pub impl Eq for Money with fn not_equal(self, other) {
  !self.equal(other)
}

///|
pub extend Money with Eq::{not_equal, equal}

///|
/// An amount from an exact number of minor units.
pub fn Money::of_minor(minor : Int64, currency : Currency) -> Money {
  { minor, currency, }
}

///|
/// An amount from whole major units, e.g. `of_units(12L, usd)` is USD 12.00.
pub fn Money::of_units(
  units : Int64,
  currency : Currency,
) -> Money raise MoneyError {
  {
    minor: mul_checked(units, currency.scale(), "units to minor units"),
    currency,
  }
}

///|
/// An amount from whole units plus a non-negative fraction in minor units.
///
/// The fraction must be smaller than one major unit, and the sign of `units`
/// decides the sign of the result: `of_parts(-2L, 50L, usd)` is -USD 2.50.
pub fn Money::of_parts(
  units : Int64,
  fraction : Int64,
  currency : Currency,
) -> Money raise MoneyError {
  let scale = currency.scale()
  if fraction < 0L || fraction >= scale {
    raise InvalidAmount(
      "{units}.{fraction}",
      "the fraction has to be in 0..\{scale}",
    )
  }
  let whole = mul_checked(units, scale, "units to minor units")
  if units < 0L {
    { minor: sub_checked(whole, fraction, "parts to minor units"), currency, }
  } else {
    { minor: add_checked(whole, fraction, "parts to minor units"), currency, }
  }
}

///|
/// The smallest amount an \`Int64\` can hold in minor units.
pub fn min_amount() -> Int64 {
  @int64.MIN_VALUE
}

///|
/// The largest amount an \`Int64\` can hold in minor units.
pub fn max_amount() -> Int64 {
  @int64.MAX_VALUE
}

///|
/// Zero in a given currency.
pub fn Money::zero(currency : Currency) -> Money {
  { minor: 0L, currency, }
}

///|
/// The number of minor units in one major unit of this amount's currency.
pub fn Money::scale(self : Money) -> Int64 {
  self.currency.scale()
}

///|
/// The whole units, truncated towards zero.
pub fn Money::units(self : Money) -> Int64 {
  self.minor / self.scale()
}

///|
/// The fraction in minor units, always non-negative.
pub fn Money::fraction(self : Money) -> Int64 {
  let remainder = self.minor % self.scale()
  if remainder < 0L {
    0L - remainder
  } else {
    remainder
  }
}

///|
/// `-1`, `0` or `1`.
pub fn Money::sign(self : Money) -> Int32 {
  if self.minor == 0L {
    0
  } else if self.minor < 0L {
    -1
  } else {
    1
  }
}

///|
pub fn Money::is_zero(self : Money) -> Bool {
  self.minor == 0L
}

///|
pub fn Money::is_positive(self : Money) -> Bool {
  self.minor > 0L
}

///|
pub fn Money::is_negative(self : Money) -> Bool {
  self.minor < 0L
}

///|
/// True when both amounts are in the same currency.
pub fn Money::same_currency(self : Money, other : Money) -> Bool {
  self.currency.same_as(other.currency)
}

///|
/// Fails unless both amounts are in the same currency.
fn Money::ensure_same_currency(
  self : Money,
  other : Money,
) -> Unit raise MoneyError {
  if !self.same_currency(other) {
    raise CurrencyMismatch(self.currency.code, other.currency.code)
  }
}

///|
pub fn Money::neg(self : Money) -> Money raise MoneyError {
  { minor: sub_checked(0L, self.minor, "negation"), currency: self.currency, }
}

///|
pub fn Money::abs(self : Money) -> Money raise MoneyError {
  if self.minor < 0L {
    self.neg()
  } else {
    self
  }
}

///|
/// Sum of two amounts in the same currency.
pub fn Money::add(self : Money, other : Money) -> Money raise MoneyError {
  self.ensure_same_currency(other)
  {
    minor: add_checked(self.minor, other.minor, "addition"),
    currency: self.currency,
  }
}

///|
/// Difference of two amounts in the same currency.
pub fn Money::sub(self : Money, other : Money) -> Money raise MoneyError {
  self.ensure_same_currency(other)
  {
    minor: sub_checked(self.minor, other.minor, "subtraction"),
    currency: self.currency,
  }
}

///|
/// Multiplication by a whole number.
pub fn Money::mul(self : Money, factor : Int32) -> Money raise MoneyError {
  self.mul_int64(factor.to_int64())
}

///|
pub fn Money::mul_int64(self : Money, factor : Int64) -> Money raise MoneyError {
  {
    minor: mul_checked(self.minor, factor, "multiplication"),
    currency: self.currency,
  }
}

///|
/// Division by a whole number, rounded once under `mode`.
pub fn Money::div_int64(
  self : Money,
  divisor : Int64,
  mode~ : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  { minor: div_round(self.minor, divisor, mode), currency: self.currency, }
}

///|
pub fn Money::div(
  self : Money,
  divisor : Int32,
  mode~ : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  self.div_int64(divisor.to_int64(), mode~)
}

///|
/// Total order over amounts of the same currency, used by sorting and by
/// `min` and `max`.
pub fn Money::compare(self : Money, other : Money) -> Int32 raise MoneyError {
  self.ensure_same_currency(other)
  if self.minor == other.minor {
    0
  } else if self.minor < other.minor {
    -1
  } else {
    1
  }
}

///|
pub fn Money::min(self : Money, other : Money) -> Money raise MoneyError {
  if self.compare(other) <= 0 {
    self
  } else {
    other
  }
}

///|
pub fn Money::max(self : Money, other : Money) -> Money raise MoneyError {
  if self.compare(other) >= 0 {
    self
  } else {
    other
  }
}

///|
/// Sum of a list of amounts. An empty list is only meaningful together with the
/// currency it would be zero in, so the caller supplies that as `fallback`.
pub fn Money::sum(
  amounts : Array[Money],
  fallback : Currency,
) -> Money raise MoneyError {
  let mut total = Money::zero(fallback)
  for amount in amounts {
    total = total.add(amount)
  }
  total
}

///|
/// Rounds the amount to the nearest multiple of `increment` minor units.
pub fn Money::round_to(
  self : Money,
  increment : Int64,
  mode~ : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  if increment <= 0L {
    raise InvalidAmount(
      increment.to_string(),
      "a rounding step has to be positive",
    )
  }
  {
    minor: mul_checked(
      div_round(self.minor, increment, mode),
      increment,
      "rounding",
    ),
    currency: self.currency,
  }
}

///|
/// Rounds to the step a cash payment of this currency is settled in.
///
/// CHF settles cash to 0.05, so 1.02 becomes 1.00 and 1.03 becomes 1.05. A
/// currency without a separate cash rule is returned unchanged.
pub fn Money::round_cash(
  self : Money,
  mode~ : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  self.round_to(self.currency.cash_increment(), mode~)
}

///|
/// The amount as a floating point number, for reporting and for plotting.
///
/// This is a lossy view. Never build an amount back from it: parse the decimal
/// text instead, or the rounding error will be reintroduced.
pub fn Money::to_double(self : Money) -> Double {
  self.minor.to_double() / self.scale().to_double()
}

///|
/// `-12.34 USD`, a debugging form. Use the format package for anything a user
/// is meant to read.
pub fn Money::debug_string(self : Money) -> String {
  "\{self.minor} \{self.currency.code}"
}
