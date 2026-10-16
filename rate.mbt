// Exchange rates as exact rationals, and conversion that rounds once.
//
// A published rate is a short decimal, so it is stored as an integer and a
// number of decimal places rather than as a Double: 7.2451 is
// `{ scaled: 72451, scale: 4 }`. Conversion multiplies the amount by the rate
// in arbitrary precision and rounds exactly once, so no intermediate rounding
// error can creep in.

///|
/// An exchange rate, exactly `scaled / 10^scale`.
pub(all) struct Rate {
  scaled : Int64
  scale : Int
} derive(Eq, Debug)

///|
/// Builds a rate from an integer and a number of decimal places.
///
/// `None` when the number of places is outside `0..=18`.
pub fn Rate::of_scaled(scaled : Int64, scale : Int) -> Rate? {
  match pow10(scale) {
    None => None
    Some(_) => Some({ scaled, scale })
  }
}

///|
/// Reads a decimal rate such as `7.2451`, up to nine decimal places.
pub fn Rate::parse(text : StringView) -> Rate raise MoneyError {
  let raw = text.trim()
  if raw.is_empty() {
    raise InvalidAmount(raw.to_owned(), "empty rate")
  }
  let negative = raw.has_prefix("-")
  let digits_text = if negative || raw.has_prefix("+") { raw[1:] } else { raw }
  let (whole_text, fraction_text) = match digits_text.find(".") {
    Some(dot) => (digits_text[0:dot], digits_text[dot + 1:])
    None => (digits_text, "")
  }
  let places = fraction_text.length()
  if places > 9 {
    raise InvalidAmount(
      raw.to_owned(),
      "at most nine decimal places are supported",
    )
  }
  let whole = if whole_text.is_empty() {
    0L
  } else {
    parse_int64_or_fail(whole_text, raw)
  }
  let fraction = if places == 0 {
    0L
  } else {
    parse_int64_or_fail(fraction_text, raw)
  }
  let power = match pow10(places) {
    Some(value) => value
    None => raise InvalidAmount(raw.to_owned(), "too many decimal places")
  }
  let scaled_whole = mul_checked(whole, power, "rate")
  let magnitude = add_checked(scaled_whole, fraction, "rate")
  let signed = if negative { 0L - magnitude } else { magnitude }
  match Rate::of_scaled(signed, places) {
    Some(rate) => rate
    None => raise InvalidAmount(raw.to_owned(), "too many decimal places")
  }
}

///|
pub fn Rate::as_double(self : Rate) -> Double {
  self.scaled.to_double() / pow10(self.scale).unwrap_or(1L).to_double()
}

///|
/// The reciprocal, with twelve decimal places and one rounding step.
pub fn Rate::inverse(
  self : Rate,
  mode? : RoundingMode = HalfEven,
) -> Rate raise MoneyError {
  if self.scaled == 0L {
    raise DivisionByZero
  }
  let target_places = 12
  let target_power = match pow10(target_places) {
    Some(value) => value
    None => raise Overflow("rate inversion")
  }
  let source_power = match pow10(self.scale) {
    Some(value) => value
    None => raise Overflow("rate inversion")
  }
  let numerator = @bigint.BigInt::from_int64(source_power).mul(
    @bigint.BigInt::from_int64(target_power),
  )
  let scaled = big_div_round(
    numerator,
    @bigint.BigInt::from_int64(self.scaled),
    mode,
  )
  { scaled, scale: target_places }
}

///|
/// Converts an amount into another currency with an explicit rate.
///
/// The amount is multiplied by the rate and by the ratio of the two minor
/// units in arbitrary precision, then rounded exactly once, so the result
/// carries no double-rounding error. No rate is fetched from anywhere: the
/// caller supplies it, which keeps conversion deterministic and offline.
pub fn Money::convert(
  self : Money,
  target : Currency,
  rate : Rate,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  let source_power = self.currency.scale()
  let target_power = target.scale()
  let rate_power = match pow10(rate.scale) {
    Some(value) => value
    None =>
      raise InvalidAmount(rate.scale.to_string(), "too many decimal places")
  }
  let numerator = @bigint.BigInt::from_int64(self.minor)
    .mul(@bigint.BigInt::from_int64(rate.scaled))
    .mul(@bigint.BigInt::from_int64(target_power))
  let denominator = @bigint.BigInt::from_int64(rate_power).mul(
    @bigint.BigInt::from_int64(source_power),
  )
  { minor: big_div_round(numerator, denominator, mode), currency: target }
}
