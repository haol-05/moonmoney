// The ISO 4217 currency value and the lookups over the generated table.
//
// A `Currency` is a plain immutable value: copy it, compare it, store it. Two
// currencies are equal when every field is equal, and `same_as` compares the
// alphabetic code alone, which is the test money arithmetic uses.

///|
pub(all) struct Currency {
  /// ISO 4217 alphabetic code, upper case, e.g. `USD`.
  code : String
  /// ISO 4217 numeric code, or 0 for a currency built with `custom`.
  numeric : Int
  /// ISO 4217 minor units: the number of decimal places an amount is stored with.
  exponent : Int
  /// The number of decimal places CLDR recommends for display, which is at most
  /// `exponent` and is smaller for currencies whose smallest unit has fallen out
  /// of use.
  display_digits : Int
  /// The decimal places a cash payment is settled in.
  cash_exponent : Int
  /// The cash rounding step, in units of `10^-cash_exponent`.
  cash_step : Int
  /// English name.
  name : String
  /// CLDR symbol, empty when the currency has none.
  symbol : String
} derive(Eq, Debug)

///|
pub extend Currency with Eq::{not_equal, equal}

///|
pub extend Currency with @debug.Debug::{to_repr}

///|
/// Ten to the power of `exponent`, or `None` when the result would not fit an
/// `Int64`. This bounds every exponent in the library at 18.
pub fn pow10(exponent : Int) -> Int64? {
  if exponent < 0 || exponent > 18 {
    return None
  }
  let mut result = 1L
  let mut index = 0
  while index < exponent {
    result = result * 10L
    index += 1
  }
  Some(result)
}

///|
/// How many minor units make one major unit: 100 for USD, 1 for JPY.
pub fn Currency::scale(self : Currency) -> Int64 {
  pow10(self.exponent).unwrap_or(1L)
}

///|
/// The step a cash payment is rounded to, in minor units.
///
/// CHF has an exponent of 2 and a cash step of 5, so this is 5 (0.05 franc).
/// DKK settles to 0.50, so this is 50. A currency without a separate cash rule
/// reports 1.
pub fn Currency::cash_increment(self : Currency) -> Int64 {
  let step = if self.cash_step < 1 { 1L } else { self.cash_step.to_int64() }
  let shift = self.exponent - self.cash_exponent
  if shift <= 0 {
    return step
  }
  step * pow10(shift).unwrap_or(1L)
}

///|
/// True when a cash payment is settled in larger steps than the minor unit.
pub fn Currency::has_cash_rounding(self : Currency) -> Bool {
  self.cash_exponent != self.exponent || self.cash_step > 1
}

///|
/// Identity of a currency for arithmetic: the alphabetic code alone.
pub fn Currency::same_as(self : Currency, other : Currency) -> Bool {
  self.code == other.code
}

///|
/// The symbol, falling back to the code when the currency has none.
pub fn Currency::display_symbol(self : Currency) -> String {
  if self.symbol == "" {
    self.code
  } else {
    self.symbol
  }
}

///|
/// `USD (US Dollar)`.
pub fn Currency::label(self : Currency) -> String {
  "\{self.code} (\{self.name})"
}

///|
/// Builds a currency that is not in the ISO 4217 table, for private or
/// historical codes and for the ISO codes that carry no minor unit.
///
/// `None` when `exponent` is outside `0..=18`, the range an `Int64` can
/// scale exactly. The code is upper-cased so lookups and comparisons stay stable.
pub fn Currency::custom(
  code : String,
  exponent : Int,
  symbol? : String = "",
) -> Currency? {
  match pow10(exponent) {
    None => None
    Some(_) => {
      let upper = code.to_upper()
      Some({
        code: upper,
        numeric: 0,
        exponent,
        display_digits: exponent,
        cash_exponent: exponent,
        cash_step: 1,
        name: upper,
        symbol,
      })
    }
  }
}

///|
/// Index over the table, built once at start-up.
let by_code : Map[String, Currency] = {
  let index : Map[String, Currency] = Map([])
  for entry in table {
    index[entry.code] = entry
  }
  index
}

///|
/// Looks an ISO 4217 currency up by its alphabetic code, ignoring case.
pub fn Currency::find(code : StringView) -> Currency? {
  by_code.get(code.to_upper().to_owned())
}

///|
/// Every currency in the registry, in code order.
pub fn Currency::all() -> Array[Currency] {
  table.copy()
}

///|
/// The alphabetic codes of the registry, in order.
pub fn Currency::known_codes() -> Array[String] {
  let codes : Array[String] = []
  for entry in table {
    codes.push(entry.code)
  }
  codes
}

///|
/// How many currencies the registry holds.
pub fn Currency::count() -> Int {
  table.length()
}

///|
/// Every currency whose code or symbol matches `token`.
///
/// The parser uses this to tell an unambiguous symbol such as `€` from an
/// ambiguous one such as `$`, which several dollar currencies share.
pub fn Currency::by_token(token : StringView) -> Array[Currency] {
  let upper = token.to_upper()
  let matches : Array[Currency] = []
  for entry in table {
    let same_code = entry.code.view() == upper
    let same_symbol = entry.symbol != "" && entry.symbol.view() == token
    if same_code || same_symbol {
      matches.push(entry)
    }
  }
  matches
}
