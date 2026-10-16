// Behaviour tests for the public money API.
//
// The helpers below turn a raising call into a plain value so that the tests
// read as arithmetic. A raise where a value was expected fails the test with
// the error's own message, which keeps the failure report useful.

///|
fn usd() -> @moonmoney.Currency {
  @moonmoney.Currency::find("USD").unwrap()
}

///|
fn jpy() -> @moonmoney.Currency {
  @moonmoney.Currency::find("JPY").unwrap()
}

///|
fn chf() -> @moonmoney.Currency {
  @moonmoney.Currency::find("CHF").unwrap()
}

///|
fn amount(minor : Int64) -> @moonmoney.Money {
  @moonmoney.Money::of_minor(minor, usd())
}

///|
fn yen(minor : Int64) -> @moonmoney.Money {
  @moonmoney.Money::of_minor(minor, jpy())
}

///|
fn add(left : @moonmoney.Money, right : @moonmoney.Money) -> @moonmoney.Money {
  left.add(right) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn sub(left : @moonmoney.Money, right : @moonmoney.Money) -> @moonmoney.Money {
  left.sub(right) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn scaled(value : @moonmoney.Money, factor : Int64) -> @moonmoney.Money {
  value.mul_int64(factor) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn divided(
  value : @moonmoney.Money,
  divisor : Int64,
  mode : @moonmoney.RoundingMode,
) -> @moonmoney.Money {
  value.div_int64(divisor, mode~) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn rounded(
  value : @moonmoney.Money,
  increment : Int64,
  mode : @moonmoney.RoundingMode,
) -> @moonmoney.Money {
  value.round_to(increment, mode~) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn cash(value : @moonmoney.Money) -> @moonmoney.Money {
  value.round_cash() catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn share(value : @moonmoney.Money, parts : Int32) -> Array[@moonmoney.Money] {
  value.allocate(parts) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn share_by(
  value : @moonmoney.Money,
  weights : Array[Int64],
) -> Array[@moonmoney.Money] {
  value.allocate_ratios(weights) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn rate(text : String) -> @moonmoney.Percent {
  @moonmoney.Percent::parse(text) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn on(
  value : @moonmoney.Money,
  percent : @moonmoney.Percent,
) -> @moonmoney.Money {
  value.percent(percent) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn with_tax(
  value : @moonmoney.Money,
  percent : @moonmoney.Percent,
) -> @moonmoney.Money {
  value.with_tax(percent) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn net_of(
  gross : @moonmoney.Money,
  percent : @moonmoney.Percent,
) -> (@moonmoney.Money, @moonmoney.Money) {
  gross.net_from_gross(percent) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn converted(
  value : @moonmoney.Money,
  target : @moonmoney.Currency,
  exchange : @moonmoney.Rate,
) -> @moonmoney.Money {
  value.convert(target, exchange) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn exchange_rate(text : String) -> @moonmoney.Rate {
  @moonmoney.Rate::parse(text) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn total_of(values : Array[@moonmoney.Money]) -> @moonmoney.Money {
  @moonmoney.Money::sum(values, usd()) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

// --- the registry -----------------------------------------------------------

///|
test "the registry holds the ISO 4217 currencies that have a minor unit" {
  assert_eq(@moonmoney.Currency::count(), 165)
  assert_eq(@moonmoney.Currency::find("usd").unwrap().code, "USD")
  assert_eq(@moonmoney.Currency::find("Jpy").unwrap().exponent, 0)
  assert_eq(@moonmoney.Currency::find("BHD").unwrap().exponent, 3)
  assert_eq(@moonmoney.Currency::find("CLF").unwrap().exponent, 4)
  assert_eq(@moonmoney.Currency::find("EUR").unwrap().symbol, "€")
  assert_eq(@moonmoney.Currency::find("USD").unwrap().numeric, 840)
  assert_true(@moonmoney.Currency::find("ZZZ") is None)
  // The metals and the fund codes carry no minor unit, so they are not fixed
  // point currencies and are not in the table.
  assert_true(@moonmoney.Currency::find("XAU") is None)
  assert_true(@moonmoney.Currency::find("XDR") is None)
  assert_eq(@moonmoney.Currency::known_codes().length(), 165)
}

///|
test "a currency outside the table can be built explicitly" {
  let points = @moonmoney.Currency::custom("LOY", 0, symbol="pt").unwrap()
  assert_eq(points.code, "LOY")
  assert_eq(points.scale(), 1L)
  assert_eq(points.display_symbol(), "pt")
  // An exponent an Int64 cannot scale exactly is refused rather than truncated.
  assert_true(@moonmoney.Currency::custom("BAD", 19) is None)
  assert_true(@moonmoney.Currency::custom("BAD", -1) is None)
}

///|
test "cash increments follow the currency" {
  assert_eq(chf().cash_increment(), 5L)
  assert_eq(chf().has_cash_rounding(), true)
  assert_eq(@moonmoney.Currency::find("DKK").unwrap().cash_increment(), 50L)
  assert_eq(jpy().cash_increment(), 1L)
  assert_eq(jpy().has_cash_rounding(), false)
  assert_eq(usd().scale(), 100L)
  assert_eq(usd().label(), "USD (US Dollar)")
}

// --- amounts ----------------------------------------------------------------

///|
test "an amount is an integer number of minor units" {
  let value = amount(1234L)
  assert_eq(value.minor, 1234L)
  assert_eq(value.units(), 12L)
  assert_eq(value.fraction(), 34L)
  assert_eq(@moonmoney.Money::of_units(12L, usd()).minor, 1200L)
  assert_eq(@moonmoney.Money::of_parts(2L, 50L, usd()).minor, 250L)
  assert_eq(@moonmoney.Money::of_parts(-2L, 50L, usd()).minor, -250L)
  assert_eq(@moonmoney.Money::of_parts(0L, 5L, usd()).minor, 5L)
  assert_eq(amount(-34L).units(), 0L)
  assert_eq(amount(-1234L).units(), -12L)
  assert_eq(amount(-1234L).fraction(), 34L)
  assert_eq(amount(0L).is_zero(), true)
  assert_eq(amount(-1L).sign(), -1)
  assert_eq(amount(1L).sign(), 1)
}

///|
test "a fraction larger than one major unit is refused" {
  let mut raised = false
  let fallback = amount(0L)
  let _ = @moonmoney.Money::of_parts(1L, 100L, usd()) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      fallback
    }
    _ => fallback
  }
  assert_eq(raised, true)
}

///|
test "addition and subtraction stay in one currency" {
  assert_eq(add(amount(1234L), amount(100L)).minor, 1334L)
  assert_eq(sub(amount(1234L), amount(1234L)).minor, 0L)
  assert_eq(add(amount(-5L), amount(5L)).minor, 0L)
  assert_eq(amount(1234L).neg().minor, -1234L)
  assert_eq(amount(-1234L).abs().minor, 1234L)
  assert_eq(amount(1234L).abs().minor, 1234L)
  assert_eq(amount(1L).to_double(), 0.01)
  assert_eq(add(yen(100L), yen(1L)).minor, 101L)
}

///|
test "combining two currencies is an error, not a silent conversion" {
  let mut seen = ""
  let _ = amount(100L).add(yen(100L)) catch {
    @moonmoney.MoneyError::CurrencyMismatch(left, right) => {
      seen = left + "/" + right
      amount(0L)
    }
    _ => amount(0L)
  }
  assert_eq(seen, "USD/JPY")
}

///|
test "an exact result that does not fit is reported" {
  let huge = amount(@moonmoney.max_amount())
  let mut raised = false
  let _ = huge.add(amount(1L)) catch {
    @moonmoney.MoneyError::Overflow(_) => {
      raised = true
      huge
    }
    _ => huge
  }
  assert_eq(raised, true)
}

///|
test "comparison, min and max order amounts" {
  assert_eq(amount(100L).compare(amount(200L)), -1)
  assert_eq(amount(200L).compare(amount(200L)), 0)
  assert_eq(amount(300L).compare(amount(200L)), 1)
  assert_eq(amount(100L).min(amount(200L)).minor, 100L)
  assert_eq(amount(100L).max(amount(200L)).minor, 200L)
  assert_eq(amount(1L).same_currency(yen(1L)), false)
}

///|
test "a list of amounts sums to the same total whatever the order" {
  let values : Array[@moonmoney.Money] = [
    amount(1999L),
    amount(-500L),
    amount(1L),
    amount(10500L),
    amount(0L),
  ]
  assert_eq(total_of(values).minor, 12000L)
  let reversed : Array[@moonmoney.Money] = [
    amount(0L),
    amount(10500L),
    amount(1L),
    amount(-500L),
    amount(1999L),
  ]
  assert_eq(total_of(reversed).minor, 12000L)
}

///|
test "multiplication and division round once" {
  assert_eq(scaled(amount(1234L), 3L).minor, 3702L)
  assert_eq(divided(amount(1000L), 3L, @moonmoney.HalfUp).minor, 333L)
  assert_eq(divided(amount(1000L), 8L, @moonmoney.HalfUp).minor, 125L)
  assert_eq(divided(amount(1001L), 2L, @moonmoney.HalfUp).minor, 501L)
  assert_eq(divided(amount(-1001L), 2L, @moonmoney.HalfUp).minor, -501L)
}

// --- rounding ---------------------------------------------------------------

///|
test "half-up rounds halves away from zero" {
  assert_eq(@moonmoney.div_round(5L, 2L, @moonmoney.HalfUp), 3L)
  assert_eq(@moonmoney.div_round(-5L, 2L, @moonmoney.HalfUp), -3L)
  assert_eq(@moonmoney.div_round(4L, 2L, @moonmoney.HalfUp), 2L)
}

///|
test "half-even rounds halves to the even neighbour" {
  assert_eq(@moonmoney.div_round(5L, 2L, @moonmoney.HalfEven), 2L)
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.HalfEven), 4L)
  assert_eq(@moonmoney.div_round(-5L, 2L, @moonmoney.HalfEven), -2L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.HalfEven), -4L)
  // Not a half: the nearest wins.
  assert_eq(@moonmoney.div_round(9L, 4L, @moonmoney.HalfEven), 2L)
  assert_eq(@moonmoney.div_round(11L, 4L, @moonmoney.HalfEven), 3L)
}

///|
test "directed modes move the way their names say" {
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.Up), 4L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.Up), -4L)
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.Down), 3L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.Down), -3L)
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.Ceiling), 4L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.Ceiling), -3L)
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.Floor), 3L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.Floor), -4L)
  // An exact division is untouched by every mode.
  for
    mode in [
      @moonmoney.HalfUp,
      @moonmoney.HalfDown,
      @moonmoney.HalfEven,
      @moonmoney.Up,
      @moonmoney.Down,
      @moonmoney.Ceiling,
      @moonmoney.Floor,
    ] {
    assert_eq(@moonmoney.div_round(-8L, 2L, mode), -4L)
  }
}

///|
test "half-down drops a bare half towards zero" {
  // A bare half -- a remainder of exactly half the divisor -- goes to the
  // neighbour nearer zero, which is the mirror of half-up.
  assert_eq(@moonmoney.div_round(5L, 2L, @moonmoney.HalfDown), 2L)
  assert_eq(@moonmoney.div_round(7L, 2L, @moonmoney.HalfDown), 3L)
  assert_eq(@moonmoney.div_round(-7L, 2L, @moonmoney.HalfDown), -3L)
  // 1.5 is a bare half and goes to 1; 1.75 and 2.75 are above it and go
  // away from zero; 2.25 is closer to 2 already.
  assert_eq(@moonmoney.div_round(6L, 4L, @moonmoney.HalfDown), 1L)
  assert_eq(@moonmoney.div_round(7L, 4L, @moonmoney.HalfDown), 2L)
  assert_eq(@moonmoney.div_round(9L, 4L, @moonmoney.HalfDown), 2L)
  assert_eq(@moonmoney.div_round(11L, 4L, @moonmoney.HalfDown), 3L)
}

///|
test "division by zero is reported" {
  let mut raised = false
  let _ = @moonmoney.div_round(1L, 0L, @moonmoney.HalfUp) catch {
    @moonmoney.MoneyError::DivisionByZero => {
      raised = true
      0L
    }
    _ => 0L
  }
  assert_eq(raised, true)
}

///|
test "a large product is exact rather than wrapped" {
  // 92233720368547758 * 100 / 100 must come back unchanged.
  assert_eq(
    @moonmoney.mul_div_round(92233720368547758L, 100L, 100L, @moonmoney.HalfUp),
    92233720368547758L,
  )
  // The same shape with a rounder that would overflow an Int64 product.
  assert_eq(@moonmoney.mul_div_round(1L, 1L, 3L, @moonmoney.HalfEven), 0L)
  assert_eq(@moonmoney.mul_div_round(2L, 1L, 3L, @moonmoney.HalfEven), 1L)
}

///|
test "rounding to a step" {
  assert_eq(rounded(amount(1234L), 5L, @moonmoney.HalfUp).minor, 1235L)
  assert_eq(rounded(amount(1232L), 5L, @moonmoney.HalfUp).minor, 1230L)
  assert_eq(rounded(amount(1233L), 5L, @moonmoney.HalfUp).minor, 1235L)
  assert_eq(rounded(amount(1234L), 100L, @moonmoney.HalfUp).minor, 1200L)
}

///|
test "cash rounding uses the currency's own step" {
  assert_eq(cash(@moonmoney.Money::of_minor(102L, chf())).minor, 100L)
  assert_eq(cash(@moonmoney.Money::of_minor(103L, chf())).minor, 105L)
  assert_eq(cash(@moonmoney.Money::of_minor(102L, usd())).minor, 102L)
  assert_eq(cash(@moonmoney.Money::of_minor(124L, jpy())).minor, 124L)
}

// --- percentages ------------------------------------------------------------

///|
test "a percentage is exact basis points" {
  assert_eq(rate("8.25%").bp(), 825L)
  assert_eq(rate("8.25").bp(), 825L)
  assert_eq(rate("-3").bp(), -300L)
  assert_eq(rate("0.5%").bp(), 50L)
  assert_eq(rate("100").bp(), 10000L)
  assert_eq(rate("8%").bp(), 800L)
  assert_eq(rate("8.25").text(), "8.25%")
  assert_eq(rate("0.5").text(), "0.5%")
  assert_eq(@moonmoney.Percent::of_whole(8L).text(), "8%")
  assert_eq(rate("-3").text(), "-3%")
  assert_eq(@moonmoney.Percent::of_bp(825L).as_double(), 0.0825)
}

///|
test "a percentage finer than a basis point is refused" {
  let mut raised = false
  let fallback = @moonmoney.Percent::zero()
  let _ = @moonmoney.Percent::parse("8.255%") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      fallback
    }
    _ => fallback
  }
  assert_eq(raised, true)
}

///|
test "applying a percentage rounds exactly once" {
  // 8.25% of 100.00 is 8.25 exactly.
  assert_eq(on(amount(10000L), rate("8.25")).minor, 825L)
  // 19% of 0.01 is 0.0019, which has to round.
  assert_eq(on(amount(1L), rate("19")).minor, 0L)
  assert_eq(on(amount(50L), rate("19")).minor, 10L)
  assert_eq(on(amount(-10000L), rate("8.25")).minor, -825L)
}

///|
test "adding and removing a percentage" {
  let net = amount(10000L)
  assert_eq(with_tax(net, rate("19")).minor, 11900L)
  assert_eq(net.add_percent(rate("8.25")).minor, 10825L)
  assert_eq(net.sub_percent(rate("10")).minor, 9000L)
}

///|
test "a ratio becomes a percentage" {
  assert_eq(@moonmoney.Percent::of_ratio(1L, 4L).bp(), 2500L)
  assert_eq(@moonmoney.Percent::of_ratio(1L, 3L).bp(), 3333L)
}

// --- allocation -------------------------------------------------------------

///|
test "an amount splits into shares that add back up" {
  let parts = share(amount(1000L), 3)
  assert_eq(parts.length(), 3)
  assert_eq(parts[0].minor, 334L)
  assert_eq(parts[1].minor, 333L)
  assert_eq(parts[2].minor, 333L)
  assert_eq(total_of(parts).minor, 1000L)
}

///|
test "allocation keeps the total for every shape" {
  for parts in [1, 2, 3, 7, 11, 100, 999] {
    for
      minor in [
        0L, 1L, 2L, 3L, 99L, 100L, 1000L, 123456L, -1L, -7L, -1000L, -123457L,
      ] {
      let split = share(amount(minor), parts)
      assert_eq(split.length(), parts)
      assert_eq(total_of(split).minor, minor)
      let mut low = split[0].minor
      let mut high = split[0].minor
      for part in split {
        if part.minor < low {
          low = part.minor
        }
        if part.minor > high {
          high = part.minor
        }
      }
      assert_true(high - low <= 1L)
    }
  }
}

///|
test "weights decide the shares and the remainder goes to the largest" {
  assert_eq(share_by(amount(100L), [3L, 1L])[0].minor, 75L)
  assert_eq(share_by(amount(100L), [3L, 1L])[1].minor, 25L)
  // 1/2, 1/3, 1/6 of 100 cents: 50, 33.33, 16.67, so the last cent goes to the
  // largest remainder, which is the third share at 2/3 of a cent against 1/3.
  let thirds = share_by(amount(100L), [3L, 2L, 1L])
  assert_eq(thirds[0].minor, 50L)
  assert_eq(thirds[1].minor, 33L)
  assert_eq(thirds[2].minor, 17L)
  assert_eq(total_of(thirds).minor, 100L)
}

///|
test "allocation by percentage and by weight agree" {
  let weights = share_by(amount(999L), [2500L, 2500L, 5000L])
  let percents = amount(999L).allocate_percents([
    @moonmoney.Percent::of_bp(2500L),
    @moonmoney.Percent::of_bp(2500L),
    @moonmoney.Percent::of_bp(5000L),
  ]) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  assert_eq(weights[0].minor, percents[0].minor)
  assert_eq(weights[1].minor, percents[1].minor)
  assert_eq(weights[2].minor, percents[2].minor)
  assert_eq(total_of(percents).minor, 999L)
}

///|
test "an allocation with nothing to divide by is refused" {
  let mut empty = false
  let _ = amount(100L).allocate(0) catch {
    @moonmoney.MoneyError::EmptyAllocation(_) => {
      empty = true
      []
    }
    _ => []
  }
  assert_eq(empty, true)
  let mut zero = false
  let _ = amount(100L).allocate_ratios([0L, 0L]) catch {
    @moonmoney.MoneyError::EmptyRatio => {
      zero = true
      []
    }
    _ => []
  }
  assert_eq(zero, true)
  let mut negative = false
  let _ = amount(100L).allocate_ratios([1L, -1L]) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      negative = true
      []
    }
    _ => []
  }
  assert_eq(negative, true)
}

// --- tax --------------------------------------------------------------------

///|
test "net plus tax, and back again" {
  let net = amount(10000L)
  let gross = with_tax(net, rate("19"))
  assert_eq(gross.minor, 11900L)
  let (recovered, tax) = net_of(gross, rate("19"))
  assert_eq(recovered.minor, 10000L)
  assert_eq(tax.minor, 1900L)
  assert_eq(add(recovered, tax).minor, gross.minor)
}

///|
test "recovering the net keeps the parts adding up for awkward rates" {
  for minor in [1L, 7L, 99L, 100L, 12345L, 999999L] {
    for text in ["3", "7.5", "19", "21", "25"] {
      let gross = amount(minor)
      let (net, tax) = net_of(gross, rate(text))
      assert_eq(add(net, tax).minor, gross.minor)
      assert_true(net.minor <= gross.minor)
    }
  }
}

///|
test "a rate that cannot be reversed is refused" {
  let mut raised = false
  let pair = (amount(0L), amount(0L))
  let _ = amount(100L).net_from_gross(rate("-100")) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      pair
    }
    _ => pair
  }
  assert_eq(raised, true)
}

///|
test "several rates produce one line each" {
  let lines = amount(10000L).tax_lines([rate("7"), rate("19")]) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].tax.minor, 700L)
  assert_eq(lines[0].gross.minor, 10700L)
  assert_eq(lines[1].tax.minor, 1900L)
  assert_eq(lines[1].gross.minor, 11900L)
}

// --- exchange ---------------------------------------------------------------

///|
test "a rate is an exact scaled integer" {
  let parsed = exchange_rate("7.2451")
  assert_eq(parsed.scaled, 72451L)
  assert_eq(parsed.scale, 4)
  assert_eq(parsed.as_double(), 7.2451)
  assert_eq(exchange_rate("0.85").scaled, 85L)
}

///|
test "conversion rounds once and respects the minor units" {
  let eur = @moonmoney.Currency::find("EUR").unwrap()
  let at_085 = @moonmoney.Rate::of_scaled(85L, 2).unwrap()
  // 100.00 USD at 0.85 is 85.00 EUR.
  assert_eq(converted(amount(10000L), eur, at_085).minor, 8500L)
  // 1 cent at 0.85 is 0.85 cents, which rounds to one cent.
  assert_eq(converted(amount(1L), eur, at_085).minor, 1L)
  let gbp = @moonmoney.Currency::find("GBP").unwrap()
  assert_eq(converted(amount(10000L), eur, at_085).currency.code, "EUR")
  assert_eq(converted(amount(0L), gbp, at_085).minor, 0L)
}

///|
test "conversion across different minor units is exact" {
  let jpy_rate = @moonmoney.Rate::of_scaled(150L, 0).unwrap()
  // 100.00 USD at 150 JPY per USD is 15000 yen, and yen have no minor unit.
  assert_eq(converted(amount(10000L), jpy(), jpy_rate).minor, 15000L)
  let bhd = @moonmoney.Currency::find("BHD").unwrap()
  let three_places = @moonmoney.Rate::of_scaled(376L, 3).unwrap()
  // 1.00 USD at 0.376 BHD is 376 fils, three decimal places.
  assert_eq(converted(amount(100L), bhd, three_places).minor, 376L)
}

///|
test "a rate inverts to twelve places" {
  let half = @moonmoney.Rate::of_scaled(2L, 0).unwrap()
  let inverted = half.inverse() catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  assert_eq(inverted.scale, 12)
  assert_eq(inverted.scaled, 500000000000L)
}

///|
test "an amount that does not fit the bounds is reported" {
  let mut raised = false
  let _ = @moonmoney.Money::of_units(@moonmoney.max_amount(), usd()) catch {
    @moonmoney.MoneyError::Overflow(_) => {
      raised = true
      amount(0L)
    }
    _ => amount(0L)
  }
  assert_eq(raised, true)
}
