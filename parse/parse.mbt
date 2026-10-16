// Reading an amount out of text.
//
// The parser is strict about two things on purpose. A currency has to be either
// declared by the caller or named by the text, because a symbol shared by
// several currencies would otherwise be guessed. And a fraction longer than the
// currency holds is refused unless the caller names a rounding mode, because a
// parser that rounds on its own is a parser that loses money quietly.

///|
fn is_digit_code(cu : UInt16) -> Bool {
  let value = cu.to_int()
  value >= 48 && value <= 57
}

///|
/// The characters accepted between digits: the two decimal marks, the space and
/// the apostrophe used for grouping, and the no-break space some locales print.
fn is_separator_code(cu : UInt16) -> Bool {
  let value = cu.to_int()
  value == 46 || value == 44 || value == 32 || value == 39 || value == 160
}

///|
fn digit_value(cu : UInt16) -> Int {
  cu.to_int() - 48
}

///|
fn is_sign_code(cu : UInt16) -> Bool {
  let value = cu.to_int()
  value == 43 || value == 45
}

///|
/// Reads a run of digits, reporting an overflow rather than wrapping.
fn digits_to_int64(digits : StringView) -> Int64 raise @moonmoney.MoneyError {
  let units = digits.code_units()
  let mut value = 0L
  for index in 0..<units.length() {
    let cu = units[index]
    if !is_digit_code(cu) {
      raise @moonmoney.InvalidAmount(digits.to_owned(), "expected digits")
    }
    value = @moonmoney.mul_checked(value, 10L, "amount")
    value = @moonmoney.add_checked(value, digit_value(cu).to_int64(), "amount")
  }
  value
}

///|
/// True when every digit of a run is zero. It is called with the digits after
/// the first dropped one, which is what separates a bare half from a value that
/// is above it.
fn tail_is_zero(rest : StringView) -> Bool {
  let units = rest.code_units()
  for index in 0..<units.length() {
    if !is_digit_code(units[index]) || units[index].to_int() != 48 {
      return false
    }
  }
  true
}

///|
/// Decides whether the dropped digits push the kept part one minor unit away
/// from zero. `first` is the first dropped digit and `rest_is_zero` says
/// whether everything after it is zero, which is what separates a bare half from
/// a value above it.
fn should_round_away(
  first : Int,
  rest_is_zero : Bool,
  negative : Bool,
  keep_is_odd : Bool,
  mode : @moonmoney.RoundingMode,
) -> Bool {
  match mode {
    @moonmoney.HalfUp => first >= 5
    @moonmoney.HalfDown => first > 5 || (first == 5 && !rest_is_zero)
    @moonmoney.HalfEven =>
      first > 5 || (first == 5 && (!rest_is_zero || keep_is_odd))
    @moonmoney.Up => true
    @moonmoney.Down => false
    @moonmoney.Ceiling => !negative
    @moonmoney.Floor => negative
  }
}

///|
/// Builds the amount from the digit runs either side of the decimal mark.
///
/// The whole part arrives with its grouping marks already removed. When the
/// fraction is longer than the currency holds, `mode` decides what happens to
/// the extra digits and `None` refuses them.
fn assemble(
  whole : StringView,
  fraction : StringView,
  exponent : Int,
  negative : Bool,
  mode : @moonmoney.RoundingMode?,
  original : StringView,
) -> Int64 raise @moonmoney.MoneyError {
  let scale = match @moonmoney.pow10(exponent) {
    Some(value) => value
    None =>
      raise @moonmoney.InvalidAmount(
        original.to_owned(),
        "unsupported exponent",
      )
  }
  let whole_value = if whole.is_empty() { 0L } else { digits_to_int64(whole) }
  let scaled_whole = @moonmoney.mul_checked(whole_value, scale, "amount")
  let fraction_length = fraction.length()
  if fraction_length <= exponent {
    let kept = if fraction_length == 0 { 0L } else { digits_to_int64(fraction) }
    let padding = if exponent == fraction_length {
      1L
    } else {
      @moonmoney.pow10(exponent - fraction_length).unwrap_or(1L)
    }
    let minor = @moonmoney.add_checked(
      scaled_whole,
      @moonmoney.mul_checked(kept, padding, "amount"),
      "amount",
    )
    return if negative { 0L - minor } else { minor }
  }
  let kept_text = fraction[0:exponent]
  let rest_text = fraction[exponent:]
  let kept = if exponent == 0 { 0L } else { digits_to_int64(kept_text) }
  let base = @moonmoney.add_checked(scaled_whole, kept, "amount")
  let rest_units = rest_text.code_units()
  let first = if rest_units.length() == 0 {
    0
  } else {
    digit_value(rest_units[0])
  }
  let rounding = match mode {
    Some(chosen) => chosen
    None =>
      raise @moonmoney.InvalidAmount(
        original.to_owned(),
        "more decimal places than the currency holds",
      )
  }
  let bump = if should_round_away(
      first,
      tail_is_zero(rest_text[1:]),
      negative,
      base % 2L != 0L,
      rounding,
    ) {
    1L
  } else {
    0L
  }
  let magnitude = @moonmoney.add_checked(base, bump, "amount")
  if negative {
    0L - magnitude
  } else {
    magnitude
  }
}

///|
/// Removes the grouping marks from a run of digits and checks that they really
/// do group in threes.
///
/// The first group may be one to three digits, which is what makes `1,234`
/// valid; every group after it has to be exactly three, which is what makes
/// `12.34` invalid rather than a quietly misread `1234`.
fn strip_grouping(
  text : StringView,
  original : StringView,
) -> String raise @moonmoney.MoneyError {
  let units = text.code_units()
  let length = units.length()
  let out = StringBuilder()
  let mut group_length = 0
  let mut group_index = 0
  let mut separator_code = 0
  for index in 0..<length {
    let cu = units[index]
    if is_separator_code(cu) {
      if group_index == 0 {
        if group_length < 1 || group_length > 3 {
          raise @moonmoney.InvalidAmount(
            original.to_owned(),
            "the first group is not 1 to 3 digits",
          )
        }
      } else if group_length != 3 {
        raise @moonmoney.InvalidAmount(
          original.to_owned(),
          "a digit group is not three digits",
        )
      }
      if separator_code == 0 {
        separator_code = cu.to_int()
      } else if separator_code != cu.to_int() {
        raise @moonmoney.InvalidAmount(
          original.to_owned(),
          "mixed grouping marks",
        )
      }
      group_index += 1
      group_length = 0
    } else {
      out.write_char(cu.to_char().unwrap_or('0'))
      group_length += 1
    }
  }
  if group_index > 0 && group_length != 3 {
    raise @moonmoney.InvalidAmount(
      original.to_owned(),
      "the last group is not three digits",
    )
  }
  out.to_string()
}

///|
/// Matches one whole token against one currency.
///
/// The symbols in the table are the disambiguated CLDR ones, so `A$` is the
/// Australian dollar, `CA$` the Canadian one, and a bare `$` is the US dollar,
/// the single currency CLDR gives that symbol. Nothing is matched inside a
/// longer word: the prefix of `Total: 12.34` is not a currency, and the parser
/// reports that instead of guessing.
fn word_matches(
  entry : @moonmoney.Currency,
  token : StringView,
  upper : StringView,
) -> Bool {
  if entry.code.view() == upper {
    return true
  }
  let symbol = entry.symbol
  symbol != "" && symbol.view() == token
}

///|
/// Every currency a token could be naming, in code order and without repeats.
fn candidates_in(token : StringView) -> Array[@moonmoney.Currency] {
  let upper = token.to_upper()
  let found : Array[@moonmoney.Currency] = []
  let seen : Map[String, Bool] = Map([])
  for entry in @moonmoney.Currency::all() {
    if word_matches(entry, token, upper) && seen.get(entry.code) is None {
      seen[entry.code] = true
      found.push(entry)
    }
  }
  found
}

///|
/// Resolves the currency from what the text named and what the caller declared.
fn resolve_currency(
  prefix : StringView,
  suffix : StringView,
  declared : @moonmoney.Currency?,
) -> @moonmoney.Currency raise @moonmoney.MoneyError {
  let found : Array[@moonmoney.Currency] = []
  let seen : Map[String, Bool] = Map([])
  for token in [prefix, suffix] {
    if token.is_empty() {
      continue
    }
    for entry in candidates_in(token) {
      if seen.get(entry.code) is None {
        seen[entry.code] = true
        found.push(entry)
      }
    }
  }
  match declared {
    Some(currency) => {
      let mut conflicting : String? = None
      for entry in found {
        if !entry.same_as(currency) {
          conflicting = Some(entry.code)
        }
      }
      match conflicting {
        Some(code) => raise @moonmoney.CurrencyMismatch(currency.code, code)
        None => currency
      }
    }
    None => {
      if found.length() == 0 {
        let mut names = prefix.to_owned()
        if names.is_empty() {
          names = suffix.to_owned()
        }
        raise @moonmoney.UnknownCurrency(
          if names.is_empty() {
            "(none)"
          } else {
            names
          },
        )
      }
      if found.length() == 1 {
        return found[0]
      }
      let codes : Array[String] = []
      for entry in found {
        codes.push(entry.code)
      }
      raise @moonmoney.AmbiguousCurrency(
        if prefix.is_empty() {
          suffix.to_owned()
        } else {
          prefix.to_owned()
        },
        codes.join(", "),
      )
    }
  }
}

///|
/// The index of the decimal mark in a run of digits, or `-1` when every mark is
/// a grouping mark.
///
/// One to `exponent` digits after a mark make it the decimal mark. More than
/// that still makes it one unless exactly three digits follow, because three is
/// the width of a grouping group: `1,235` is one thousand two hundred thirty
/// five, while `1.2345` can only be a fraction, and a fraction longer than the
/// currency holds has to be refused or rounded rather than quietly read as a
/// larger whole number.
fn decimal_index(numeric : StringView, exponent : Int) -> Int {
  let units = numeric.code_units()
  let length = units.length()
  let mut last = -1
  for index in 0..<length {
    if is_separator_code(units[index]) {
      last = index
    }
  }
  if last < 0 {
    return -1
  }
  let digits_after = length - last - 1
  if digits_after >= 1 && digits_after <= exponent {
    return last
  }
  if digits_after >= 1 && digits_after != 3 {
    return last
  }
  -1
}

///|
/// Parses an amount, with the currency coming from the text when it can.
///
/// The text may carry the code (`USD 12.34`), one of the disambiguated symbols
/// (`CA$12.34`), a leading or trailing sign, or accounting parentheses.
pub fn amount(
  text : StringView,
) -> @moonmoney.Money raise @moonmoney.MoneyError {
  parse_amount(text, None, None)
}

///|
/// Parses an amount in a currency the caller states.
///
/// If the text also names a currency, the two have to agree.
pub fn amount_in(
  text : StringView,
  currency : @moonmoney.Currency,
) -> @moonmoney.Money raise @moonmoney.MoneyError {
  parse_amount(text, Some(currency), None)
}

///|
/// Like `amount_in`, but a fraction longer than the currency holds is rounded
/// once under `mode` instead of being refused.
pub fn amount_in_rounded(
  text : StringView,
  currency : @moonmoney.Currency,
  mode? : @moonmoney.RoundingMode = @moonmoney.HalfEven,
) -> @moonmoney.Money raise @moonmoney.MoneyError {
  parse_amount(text, Some(currency), Some(mode))
}

///|
fn parse_amount(
  text : StringView,
  declared : @moonmoney.Currency?,
  mode : @moonmoney.RoundingMode?,
) -> @moonmoney.Money raise @moonmoney.MoneyError {
  let raw = text.trim()
  if raw.is_empty() {
    raise @moonmoney.InvalidAmount(raw.to_owned(), "empty text")
  }
  let units = raw.code_units()
  let length = units.length()
  let mut head = 0
  let mut tail = length
  let mut negative = false
  if length >= 2 && units[0].to_int() == 40 && units[length - 1].to_int() == 41 {
    negative = true
    head = 1
    tail = length - 1
  }
  while head < tail && is_sign_code(units[head]) {
    if units[head].to_int() == 45 {
      negative = !negative
    }
    head += 1
  }
  while tail > head && is_sign_code(units[tail - 1]) {
    if units[tail - 1].to_int() == 45 {
      negative = !negative
    }
    tail -= 1
  }
  let mut first = -1
  let mut last = -1
  for index in head..<tail {
    if is_digit_code(units[index]) {
      if first < 0 {
        first = index
      }
      last = index
    }
  }
  if first < 0 {
    raise @moonmoney.InvalidAmount(raw.to_owned(), "no digits")
  }
  // A decimal mark glued to the number (`.5`, `12.`) belongs to the number.
  while first > head &&
        (units[first - 1].to_int() == 46 || units[first - 1].to_int() == 44) {
    first -= 1
  }
  while last + 1 < tail &&
        (units[last + 1].to_int() == 46 || units[last + 1].to_int() == 44) {
    last += 1
  }
  let prefix = raw[head:first].trim()
  let suffix = raw[last + 1:tail].trim()
  let currency = resolve_currency(prefix, suffix, declared)
  // Drop a trailing mark left over from `12.`; it declares no fraction.
  let mut numeric_end = last + 1
  while numeric_end - 1 > first &&
        (
          units[numeric_end - 1].to_int() == 46 ||
          units[numeric_end - 1].to_int() == 44
        ) {
    numeric_end -= 1
  }
  let numeric = raw[first:numeric_end]
  let mark = decimal_index(numeric, currency.exponent)
  let (whole_text, fraction_text) = if mark >= 0 {
    (numeric[0:mark], numeric[mark + 1:numeric.length()])
  } else {
    (numeric, "")
  }
  let whole = strip_grouping(whole_text, raw)
  let fraction = fraction_text.to_owned()
  let minor = assemble(
    whole.view(),
    fraction.view(),
    currency.exponent,
    negative,
    mode,
    raw,
  )
  { minor, currency }
}
