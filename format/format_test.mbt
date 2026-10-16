// Rendering amounts.

///|
fn usd() -> @moonmoney.Currency {
  @moonmoney.Currency::find("USD").unwrap()
}

///|
fn inr() -> @moonmoney.Currency {
  @moonmoney.Currency::find("INR").unwrap()
}

///|
fn render(money : @moonmoney.Money, style : @format.MoneyStyle) -> String {
  @format.format(money, style~) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn render_default(money : @moonmoney.Money) -> String {
  @format.format(money) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn by_locale(money : @moonmoney.Money, locale : String) -> String {
  let style = @format.MoneyStyle::for_locale(locale).unwrap()
  render(money, style)
}

///|
test "grouping follows the locale's width" {
  assert_eq(@format.group_digits("12345678", ",", 3, 3), "12,345,678")
  assert_eq(@format.group_digits("12345678", ",", 3, 2), "1,23,45,678")
  assert_eq(@format.group_digits("123", ",", 3, 3), "123")
  assert_eq(@format.group_digits("1234", ",", 3, 3), "1,234")
  assert_eq(@format.group_digits("1234", ".", 3, 3), "1.234")
}

///|
test "the standard style prints a symbol in front" {
  let money = @moonmoney.Money::of_minor(123456L, usd())
  assert_eq(render_default(money), "$1,234.56")
  assert_eq(render(money, @format.MoneyStyle::code_first()), "USD 1,234.56")
  assert_eq(render(money, @format.MoneyStyle::plain()), "1234.56")
  assert_eq(render(money, @format.MoneyStyle::accounting()), "$1,234.56")
}

///|
test "negatives follow the chosen style" {
  let money = @moonmoney.Money::of_minor(-123456L, usd())
  assert_eq(render(money, @format.MoneyStyle::standard()), "-$1,234.56")
  assert_eq(render(money, @format.MoneyStyle::accounting()), "($1,234.56)")
  let trailing = @format.MoneyStyle::standard().with_negative(
    @format.TrailingMinus,
  )
  assert_eq(render(money, trailing), "$1,234.56-")
}

///|
test "the number of places can be chosen" {
  let money = @moonmoney.Money::of_minor(123456L, usd())
  assert_eq(
    render(money, @format.MoneyStyle::standard().with_digits(0)),
    "$1,235",
  )
  assert_eq(
    render(money, @format.MoneyStyle::standard().with_digits(4)),
    "$1,234.5600",
  )
  assert_eq(
    render(money, @format.MoneyStyle::standard().with_digits(1)),
    "$1,234.6",
  )
  // Fewer places rounds half to even, in both directions.
  let half = @moonmoney.Money::of_minor(123450L, usd())
  assert_eq(
    render(half, @format.MoneyStyle::standard().with_digits(0)),
    "$1,234",
  )
}

///|
test "the currency decides the places when the style does not" {
  assert_eq(
    render_default(
      @moonmoney.Money::of_minor(
        1234L,
        @moonmoney.Currency::find("JPY").unwrap(),
      ),
    ),
    "¥1,234",
  )
  assert_eq(
    render_default(
      @moonmoney.Money::of_minor(
        1234L,
        @moonmoney.Currency::find("BHD").unwrap(),
      ),
    ),
    "BHD1.234",
  )
  assert_eq(
    render_default(
      @moonmoney.Money::of_minor(
        12345L,
        @moonmoney.Currency::find("CLF").unwrap(),
      ),
    ),
    "CLF1.2345",
  )
}

///|
test "locale presets lay the amount out the local way" {
  let money = @moonmoney.Money::of_minor(123456L, usd())
  assert_eq(by_locale(money, "en-US"), "$1,234.56")
  assert_eq(by_locale(money, "de-DE"), "1.234,56 $")
  assert_eq(by_locale(money, "fr-FR"), "1 234,56 $")
  assert_eq(by_locale(money, "sv-SE"), "1 234,56 $")
  // The Indian system groups the last three digits and then in twos.
  assert_eq(
    by_locale(@moonmoney.Money::of_minor(12345678L, inr()), "en-IN"),
    "₹1,23,456.78",
  )
  assert_eq(by_locale(money, "zh-CN"), "$1,234.56")
  // An unknown tag reports itself instead of guessing a layout.
  assert_true(@format.MoneyStyle::for_locale("xx-YY") is None)
  assert_true(@format.MoneyStyle::for_locale("de-AT") is Some(_))
}

///|
test "a locale falls back to its language" {
  let money = @moonmoney.Money::of_minor(123456L, usd())
  assert_eq(by_locale(money, "de-CH"), by_locale(money, "de-DE"))
  assert_eq(by_locale(money, "EN"), by_locale(money, "en-US"))
}

///|
test "amounts render one per line" {
  let amounts : Array[@moonmoney.Money] = [
    @moonmoney.Money::of_minor(100L, usd()),
    @moonmoney.Money::of_minor(-250L, usd()),
  ]
  let text = @format.format_lines(amounts, style=@format.MoneyStyle::plain()) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  assert_eq(text, "1.00\n-2.50")
}
