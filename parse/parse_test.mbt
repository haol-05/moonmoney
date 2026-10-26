// Reading amounts back from text.

///|
fn usd() -> @moonmoney.Currency {
  @moonmoney.Currency::find("USD").unwrap()
}

///|
fn parsed(text : String) -> @moonmoney.Money {
  @parse.amount(text) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn parsed_in(text : String, code : String) -> @moonmoney.Money {
  let currency = @moonmoney.Currency::find(code).unwrap()
  @parse.amount_in(text, currency) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn parsed_rounded(
  text : String,
  code : String,
  mode : @moonmoney.RoundingMode,
) -> @moonmoney.Money {
  let currency = @moonmoney.Currency::find(code).unwrap()
  @parse.amount_in_rounded(text, currency, mode~) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
test "a code in the text settles the currency" {
  assert_eq(parsed("USD 12.34").minor, 1234L)
  assert_eq(parsed("USD 12.34").currency.code, "USD")
  assert_eq(parsed("12.34 USD").minor, 1234L)
  assert_eq(parsed("usd 12.34").minor, 1234L)
}

///|
test "the caller can settle the currency" {
  assert_eq(parsed_in("12.34", "USD").minor, 1234L)
  assert_eq(parsed_in("$12.34", "USD").minor, 1234L)
  assert_eq(parsed_in("¥1,234", "JPY").minor, 1234L)
  assert_eq(parsed_in("1,234", "JPY").minor, 1234L)
}

///|
test "the thousand and decimal marks are told apart" {
  // The last mark is a decimal mark only when one to three digits follow it,
  // which is what separates the English and the continental readings.
  assert_eq(parsed_in("1,234.56", "USD").minor, 123456L)
  assert_eq(parsed_in("1.234,56", "USD").minor, 123456L)
  assert_eq(parsed_in("1 234,56", "USD").minor, 123456L)
  assert_eq(parsed_in("1'234.56", "USD").minor, 123456L)
  assert_eq(parsed_in("1234.5", "USD").minor, 123450L)
  assert_eq(parsed_in(".5", "USD").minor, 50L)
  assert_eq(parsed_in("12.", "USD").minor, 1200L)
  // Three digits after the mark is not a fraction of a two-place currency, so
  // the mark is read as grouping.
  assert_eq(parsed_in("1.234", "USD").minor, 123400L)
  assert_eq(parsed_in("1,234", "USD").minor, 123400L)
  assert_eq(parsed_in("1234", "USD").minor, 123400L)
}

///|
test "signs, parentheses and accounting negatives" {
  assert_eq(parsed_in("-5.00", "USD").minor, -500L)
  assert_eq(parsed_in("5.00-", "USD").minor, -500L)
  assert_eq(parsed_in("(5.00)", "USD").minor, -500L)
  assert_eq(parsed_in("+5.00", "USD").minor, 500L)
  assert_eq(parsed_in("-$1,234.56", "USD").minor, -123456L)
}

///|
test "the currency in the text has to agree with the caller" {
  let mut seen = ""
  let _ = @parse.amount_in("EUR 12.34", usd()) catch {
    @moonmoney.MoneyError::CurrencyMismatch(left, right) => {
      seen = left + "/" + right
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(seen, "USD/EUR")
}

///|
test "the disambiguated symbols pick the right currency" {
  // The table carries the CLDR symbols, which are the disambiguated ones, so a
  // symbol alone settles the currency without a guess.
  assert_eq(parsed("$12.34").currency.code, "USD")
  assert_eq(parsed("A$12.34").currency.code, "AUD")
  assert_eq(parsed("CA$12.34").currency.code, "CAD")
  assert_eq(parsed("€12.34").currency.code, "EUR")
  assert_eq(parsed("¥1,234").currency.code, "JPY")
  assert_eq(parsed("CN¥12.34").currency.code, "CNY")
  // A symbol is only recognised as a whole token.
  assert_eq(@moonmoney.Currency::by_token("$").length(), 1)
  assert_eq(@moonmoney.Currency::by_token("CA$")[0].code, "CAD")
  assert_eq(@moonmoney.Currency::by_token("kr").length(), 0)
}

///|
test "text that names no currency and declares none is reported" {
  let mut raised = false
  let _ = @parse.amount("Total: 12.34") catch {
    @moonmoney.MoneyError::UnknownCurrency(_) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}

///|
test "a fraction longer than the currency holds is refused" {
  let mut raised = false
  let _ = @parse.amount_in("USD 1.2345", usd()) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}

///|
test "excess precision can be rounded on request, exactly once" {
  // Four fractional digits cannot be a grouping group, so they are a fraction
  // that has to be dealt with.
  assert_eq(parsed_rounded("1.2345", "USD", @moonmoney.HalfEven).minor, 123L)
  assert_eq(parsed_rounded("1.2355", "USD", @moonmoney.HalfEven).minor, 124L)
  // A bare half goes to the even neighbour: 1.2250 keeps 122, 1.2350 takes 124.
  assert_eq(parsed_rounded("1.2250", "USD", @moonmoney.HalfEven).minor, 122L)
  assert_eq(parsed_rounded("1.2350", "USD", @moonmoney.HalfEven).minor, 124L)
  assert_eq(parsed_rounded("1.2350", "USD", @moonmoney.HalfUp).minor, 124L)
  // Yen have no minor unit at all, so every fraction is excess.
  assert_eq(parsed_rounded("12.34", "JPY", @moonmoney.HalfEven).minor, 12L)
  assert_eq(parsed_rounded("12.5", "JPY", @moonmoney.HalfEven).minor, 12L)
  assert_eq(parsed_rounded("13.5", "JPY", @moonmoney.HalfEven).minor, 14L)
}

///|
test "grouping that is not in threes is refused" {
  let mut raised = false
  let _ = @parse.amount_in("1.2345.6", usd()) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}

///|
test "text with no digits is refused" {
  let mut raised = false
  let _ = @parse.amount_in("USD", usd()) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}

///|
test "the three and four place currencies keep their places" {
  assert_eq(parsed_in("1.234", "BHD").minor, 1234L)
  assert_eq(parsed_in("1.2345", "CLF").minor, 12345L)
  assert_eq(parsed_in("1234", "JPY").minor, 1234L)
  assert_eq(parsed_in("1,234", "JPY").minor, 1234L)
}

///|
test "the refusal paths are reachable" {
  // No currency anywhere in the text, and none declared.
  let mut none = false
  let _ = @parse.amount("12.34") catch {
    @moonmoney.MoneyError::UnknownCurrency(_) => {
      none = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(none, true)
  // Two currencies named at once.
  let mut ambiguous = false
  let _ = @parse.amount("USD 12.34 EUR") catch {
    @moonmoney.MoneyError::AmbiguousCurrency(_, codes) => {
      ambiguous = codes.contains("USD") && codes.contains("EUR")
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(ambiguous, true)
  // Blank input.
  let mut blank = false
  let _ = @parse.amount("   ") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      blank = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(blank, true)
  // Grouping that is not in threes in the middle of the number.
  let mut bad_group = false
  let _ = @parse.amount("USD 1,2345,678") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      bad_group = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(bad_group, true)
  // Two different grouping marks in one number.
  let mut mixed = false
  let _ = @parse.amount("USD 1,234.567") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      mixed = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(mixed, true)
}

///|
test "every rounding mode is accepted when excess precision is rounded" {
  // 1.2250 is a bare half, so half-down keeps 122 and half-up takes 123.
  assert_eq(parsed_rounded("1.2250", "USD", @moonmoney.HalfDown).minor, 122L)
  assert_eq(parsed_rounded("1.2250", "USD", @moonmoney.HalfUp).minor, 123L)
  assert_eq(parsed_rounded("1.2310", "USD", @moonmoney.Up).minor, 124L)
  assert_eq(parsed_rounded("1.2310", "USD", @moonmoney.Down).minor, 123L)
  assert_eq(parsed_rounded("1.2310", "USD", @moonmoney.Ceiling).minor, 124L)
  // A negative amount rounds away from zero in the negative direction.
  assert_eq(parsed_rounded("-1.2345", "USD", @moonmoney.HalfEven).minor, -123L)
  assert_eq(parsed_rounded("-1.2355", "USD", @moonmoney.HalfEven).minor, -124L)
  // Floor keeps the lower neighbour whatever the sign, so a positive amount
  // truncates and a negative one moves further from zero.
  assert_eq(parsed_rounded("1.2355", "USD", @moonmoney.Floor).minor, 123L)
  assert_eq(parsed_rounded("-1.2310", "USD", @moonmoney.Floor).minor, -124L)
  // A trailing decimal mark declares no fraction.
  assert_eq(parsed_in("5.", "USD").minor, 500L)
}

///|
test "a leading grouping mark leaves an empty first group" {
  let mut raised = false
  let _ = @parse.amount_in(",123", usd()) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}

///|
test "a hand-built currency with an impossible exponent is refused" {
  // Currency is a public record, so a caller can build one the constructors
  // would have rejected; the parser has to notice instead of wrapping.
  let broken : @moonmoney.Currency = {
    code: "BAD",
    numeric: 0,
    exponent: 19,
    display_digits: 19,
    cash_exponent: 19,
    cash_step: 1,
    name: "Broken",
    symbol: "",
  }
  let mut raised = false
  let _ = @parse.amount_in("1", broken) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      @moonmoney.Money::zero(usd())
    }
    _ => @moonmoney.Money::zero(usd())
  }
  assert_eq(raised, true)
}
