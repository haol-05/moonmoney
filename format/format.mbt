// Rendering an amount as text.
//
// The amount is exact; the rendering is a choice. A style says which decimal
// places to show, how to group digits, which decimal mark to use, whether to
// print a symbol, a code or nothing, and how to mark a negative. Every style
// keeps the value reachable again through the parser.

///|
/// How a negative amount is written.
pub(all) enum NegativeStyle {
  /// `-1,234.56`
  Minus
  /// `(1,234.56)`, as accounting does
  Parentheses
  /// `1,234.56-`, as some ledgers do
  TrailingMinus
} derive(Eq, Debug)

///|
pub extend NegativeStyle with Eq::{not_equal, equal}

///|
pub extend NegativeStyle with @debug.Debug::{to_repr}

///|
/// Where the symbol or code goes.
pub(all) enum SymbolPosition {
  Before
  After
} derive(Eq, Debug)

///|
pub extend SymbolPosition with Eq::{not_equal, equal}

///|
pub extend SymbolPosition with @debug.Debug::{to_repr}

///|
/// What identifies the currency in the output. Named \`UnitLabel\` rather than
/// \`Unit\` so that it does not shadow the built-in unit type.
pub(all) enum UnitLabel {
  /// The currency symbol, falling back to the code when there is none.
  Symbol
  /// The ISO alphabetic code.
  Code
  /// Nothing; the number stands alone.
  Bare
} derive(Eq, Debug)

///|
pub extend UnitLabel with Eq::{not_equal, equal}

///|
pub extend UnitLabel with @debug.Debug::{to_repr}

///|
/// How to lay an amount out.
pub(all) struct MoneyStyle {
  unit : UnitLabel
  position : SymbolPosition
  /// A space between the unit and the number.
  space : Bool
  /// Group the whole part.
  group : Bool
  group_separator : String
  decimal_separator : String
  /// How many decimal places to show; `None` follows the currency.
  digits : Int?
  /// Digits in the rightmost group.
  primary_group : Int
  /// Digits in every group to its left, which is 2 for the Indian system.
  secondary_group : Int
  negative : NegativeStyle
} derive(Eq, Debug)

///|
pub extend MoneyStyle with Eq::{not_equal, equal}

///|
pub extend MoneyStyle with @debug.Debug::{to_repr}

///|
/// `$1,234.56`, the common English layout.
pub fn MoneyStyle::standard() -> MoneyStyle {
  {
    unit: Symbol,
    position: Before,
    space: false,
    group: true,
    group_separator: ",",
    decimal_separator: ".",
    digits: None,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  }
}

///|
/// `($1,234.56)` for a negative amount.
pub fn MoneyStyle::accounting() -> MoneyStyle {
  { ..MoneyStyle::standard(), negative: Parentheses }
}

///|
/// `USD 1,234.56`, which stays unambiguous in a log or a CSV column.
pub fn MoneyStyle::code_first() -> MoneyStyle {
  { ..MoneyStyle::standard(), unit: Code, space: true }
}

///|
/// `1234.56`, no grouping and no unit, for a machine-readable field.
pub fn MoneyStyle::plain() -> MoneyStyle {
  { ..MoneyStyle::standard(), unit: Bare, group: false }
}

///|
/// The standard layout with other separators.
pub fn MoneyStyle::with_separators(
  group_separator : String,
  decimal_separator : String,
) -> MoneyStyle {
  { ..MoneyStyle::standard(), group_separator, decimal_separator }
}

///|
/// The same style with a fixed number of decimal places.
pub fn MoneyStyle::with_digits(self : MoneyStyle, digits : Int) -> MoneyStyle {
  { ..self, digits: Some(digits) }
}

///|
/// The same style with another way of marking a negative amount.
pub fn MoneyStyle::with_negative(
  self : MoneyStyle,
  negative : NegativeStyle,
) -> MoneyStyle {
  { ..self, negative, }
}

///|
/// The same style with another position for the unit.
pub fn MoneyStyle::with_position(
  self : MoneyStyle,
  position : SymbolPosition,
) -> MoneyStyle {
  { ..self, position, }
}

///|
/// Inserts grouping marks into a run of digits.
///
/// The rightmost group takes `primary` digits and every group to its left
/// `secondary`, which is what makes the Indian 12,34,567 expressible.
pub fn group_digits(
  digits : StringView,
  separator : String,
  primary : Int,
  secondary : Int,
) -> String {
  let length = digits.length()
  let first = if primary < 1 { 3 } else { primary }
  let rest = if secondary < 1 { first } else { secondary }
  if length <= first {
    return digits.to_owned()
  }
  let chunks : Array[String] = []
  let mut end = length
  let mut rightmost = true
  while end > 0 {
    let size = if rightmost { first } else { rest }
    let start = if end > size { end - size } else { 0 }
    chunks.push(digits[start:end].to_owned())
    end = start
    rightmost = false
  }
  let out = StringBuilder()
  let mut index = chunks.length() - 1
  while index >= 0 {
    out.write_string(chunks[index])
    if index > 0 {
      out.write_string(separator)
    }
    index -= 1
  }
  out.to_string()
}

///|
/// Renders an amount.
///
/// When the style asks for fewer decimal places than the currency holds, the
/// value is rounded half to even, the convention accounting uses, and the
/// rounding is done once. Asking for more places pads with zeros and never
/// invents precision.
pub fn format(
  money : @moonmoney.Money,
  style? : MoneyStyle,
) -> String raise @moonmoney.MoneyError {
  let chosen = style.unwrap_or(MoneyStyle::standard())
  let currency = money.currency
  let digits = chosen.digits.unwrap_or(currency.exponent)
  if digits < 0 || digits > 18 {
    raise @moonmoney.InvalidAmount(
      digits.to_string(),
      "unsupported number of decimal places",
    )
  }
  let negative = money.minor < 0L
  if money.minor == @moonmoney.min_amount() {
    raise @moonmoney.Overflow("formatting the smallest representable amount")
  }
  let magnitude = if negative { 0L - money.minor } else { money.minor }
  let local_scale = @moonmoney.pow10(digits).unwrap_or(1L)
  let drop = currency.exponent - digits
  let scaled = if drop > 0 {
    let divisor = @moonmoney.pow10(drop).unwrap_or(1L)
    @moonmoney.div_round(magnitude, divisor, @moonmoney.HalfEven)
  } else if drop < 0 {
    @moonmoney.mul_checked(
      magnitude,
      @moonmoney.pow10(0 - drop).unwrap_or(1L),
      "formatting",
    )
  } else {
    magnitude
  }
  let whole = scaled / local_scale
  let fraction = scaled % local_scale
  let whole_text = if chosen.group {
    group_digits(
      whole.to_string(),
      chosen.group_separator,
      chosen.primary_group,
      chosen.secondary_group,
    )
  } else {
    whole.to_string()
  }
  let number = if digits == 0 {
    whole_text
  } else {
    let fraction_text = fraction.to_string().pad_start(digits, '0')
    whole_text + chosen.decimal_separator + fraction_text
  }
  let unit_text = match chosen.unit {
    Symbol => currency.display_symbol()
    Code => currency.code
    Bare => ""
  }
  let body = if unit_text == "" {
    number
  } else {
    let gap = if chosen.space { " " } else { "" }
    match chosen.position {
      Before => unit_text + gap + number
      After => number + gap + unit_text
    }
  }
  if !negative {
    return body
  }
  match chosen.negative {
    Minus => "-" + body
    Parentheses => "(" + body + ")"
    TrailingMinus => body + "-"
  }
}

///|
/// Renders several amounts, one per line, which is what a report wants.
pub fn format_lines(
  amounts : Array[@moonmoney.Money],
  style? : MoneyStyle,
) -> String raise @moonmoney.MoneyError {
  let chosen = style.unwrap_or(MoneyStyle::standard())
  let lines : Array[String] = []
  for amount in amounts {
    lines.push(format(amount, style=chosen))
  }
  lines.join("\n")
}
