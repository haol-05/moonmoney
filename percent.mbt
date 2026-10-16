// Percentages as exact basis points, and the operations that apply them.
//
// A percentage stated by a tax authority or a price list is a decimal with a
// small number of places, so it is stored as basis points -- an integer number
// of hundredths of a percent -- rather than as a Double. 8.25% is 825 basis
// points, and applying it to an amount stays exact until the single rounding
// step at the end.

///|
/// A percentage as an exact number of basis points: 1% is 100 bp.
pub(all) struct Percent {
  bp : Int64
} derive(Eq, Debug)

///|
let big_hundred : @bigint.BigInt = @bigint.BigInt::from_int(100)

///|
pub fn Percent::of_bp(bp : Int64) -> Percent {
  { bp, }
}

///|
/// A whole number of percent, e.g. `of_whole(8L)` is 8%.
pub fn Percent::of_whole(whole : Int64) -> Percent {
  { bp: whole * 100L }
}

///|
pub fn Percent::zero() -> Percent {
  { bp: 0L }
}

///|
pub fn Percent::bp(self : Percent) -> Int64 {
  self.bp
}

///|
pub fn Percent::is_zero(self : Percent) -> Bool {
  self.bp == 0L
}

///|
pub fn Percent::as_double(self : Percent) -> Double {
  self.bp.to_double() / 10000.0
}

///|
/// `825` basis points becomes `8.25%`, and trailing zeros are dropped.
pub fn Percent::text(self : Percent) -> String {
  let negative = self.bp < 0L
  let magnitude = if negative {
    @bigint.BigInt::from_int64(self.bp).neg()
  } else {
    @bigint.BigInt::from_int64(self.bp)
  }
  let whole = magnitude.div(big_hundred)
  let fraction = magnitude.mod(big_hundred).to_int()
  let body = if fraction == 0 {
    whole.to_string()
  } else if fraction % 10 == 0 {
    "\{whole}.\{fraction / 10}"
  } else if fraction < 10 {
    "\{whole}.0\{fraction}"
  } else {
    "\{whole}.\{fraction}"
  }
  if negative {
    "-\{body}%"
  } else {
    "\{body}%"
  }
}

///|
/// Reads a percentage such as `8.25%`, `8.25` or `-8`.
///
/// A leading or trailing percent sign is accepted and ignored. At most two
/// decimal places are accepted, because a basis point is the smallest unit the
/// type holds; anything finer is refused rather than silently rounded.
pub fn Percent::parse(text : StringView) -> Percent raise MoneyError {
  let raw = text.trim()
  let unsigned = match raw.strip_suffix("%") {
    Some(inner) => inner.trim()
    None =>
      match raw.strip_prefix("%") {
        Some(inner) => inner.trim()
        None => raw
      }
  }
  if unsigned.is_empty() {
    raise InvalidAmount(raw.to_owned(), "empty percentage")
  }
  let negative = unsigned.has_prefix("-")
  let digits_text = if negative || unsigned.has_prefix("+") {
    unsigned[1:]
  } else {
    unsigned
  }
  if digits_text.is_empty() {
    raise InvalidAmount(raw.to_owned(), "no digits after the sign")
  }
  let (whole_text, fraction_text) = match digits_text.find(".") {
    Some(dot) => (digits_text[0:dot], digits_text[dot + 1:])
    None => (digits_text, "")
  }
  let fraction_digits = fraction_text.length()
  if fraction_digits > 2 {
    raise InvalidAmount(
      raw.to_owned(),
      "at most two decimal places are supported",
    )
  }
  if digits_text.contains(".") && whole_text.is_empty() && fraction_digits == 0 {
    raise InvalidAmount(raw.to_owned(), "no digits")
  }
  let whole = if whole_text.is_empty() {
    0L
  } else {
    parse_int64_or_fail(whole_text, raw)
  }
  let fraction = if fraction_digits == 0 {
    0L
  } else {
    let digits = parse_int64_or_fail(fraction_text, raw)
    if fraction_digits == 1 {
      digits * 10L
    } else {
      digits
    }
  }
  let scaled = mul_checked(whole, 100L, "percentage")
  let magnitude = add_checked(scaled, fraction, "percentage")
  Percent::of_bp(if negative { 0L - magnitude } else { magnitude })
}

///|
/// Parses an integer, reporting the original text when it does not fit.
fn parse_int64_or_fail(
  text : StringView,
  original : StringView,
) -> Int64 raise MoneyError {
  @string.parse_int64(text) catch {
    _ => raise InvalidAmount(original.to_owned(), "not a number")
  }
}

///|
/// A ratio as a percentage, rounded to the nearest basis point.
pub fn Percent::of_ratio(
  numerator : Int64,
  denominator : Int64,
  mode? : RoundingMode = HalfUp,
) -> Percent raise MoneyError {
  { bp: mul_div_round(numerator, 10000L, denominator, mode) }
}

///|
/// The part of an amount that the percentage represents.
///
/// This is the rounding boundary of a tax or discount calculation: the product
/// is exact and exactly one rounding step is applied.
pub fn Money::percent(
  self : Money,
  percent : Percent,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  {
    minor: mul_div_round(self.minor, percent.bp(), 10000L, mode),
    currency: self.currency,
  }
}

///|
/// The amount plus the percentage, e.g. net plus tax.
pub fn Money::add_percent(
  self : Money,
  percent : Percent,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  let part = self.percent(percent, mode~)
  self.add(part)
}

///|
/// The amount with the percentage taken off, e.g. a discount.
pub fn Money::sub_percent(
  self : Money,
  percent : Percent,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  let part = self.percent(percent, mode~)
  self.sub(part)
}
