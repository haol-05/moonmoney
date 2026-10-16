// A runnable tour of MoonMoney.
//
//   moon run examples/demo
//
// Each section prints what the library computes, including the parts that are
// easy to get wrong with floating point: percentages, tax, splitting a bill and
// converting between currencies.

///|
fn usd() -> @moonmoney.Currency {
  @moonmoney.Currency::find("USD").unwrap()
}

///|
fn amount(minor : Int64) -> @moonmoney.Money {
  @moonmoney.Money::of_minor(minor, usd())
}

///|
fn heading(title : String) -> Unit {
  println("")
  println("== \{title} ==")
}

///|
/// Renders an amount, failing loudly if the library reports an error, which in
/// the demo would mean a bug rather than bad input.
fn show(money : @moonmoney.Money, style : @format.MoneyStyle) -> String {
  @format.format(money, style~) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
}

///|
fn percent(text : String) -> @moonmoney.Percent {
  @moonmoney.Percent::parse(text) catch {
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
fn read(text : String) -> @moonmoney.Money? {
  Some(@parse.amount(text)) catch {
    _ => None
  }
}

///|
fn read_result(text : String) -> String {
  match read(text) {
    Some(money) => show(money, @format.MoneyStyle::code_first())
    None => "refused"
  }
}

///|
/// Reads an amount in a stated currency; used for the inputs that carry no
/// currency of their own.
fn read_in_result(text : String, code : String) -> String {
  let currency = @moonmoney.Currency::find(code).unwrap()
  let money = @parse.amount_in(text, currency) catch { _ => return "refused" }
  show(money, @format.MoneyStyle::code_first())
}

///|
fn main {
  println("MoonMoney: exact money arithmetic on ISO 4217 currencies")

  heading("the registry")
  println(
    "\{@moonmoney.Currency::count()} currencies with a defined minor unit",
  )
  for code in ["USD", "JPY", "BHD", "CLF"] {
    let currency = @moonmoney.Currency::find(code).unwrap()
    println(
      "  \{currency.label()}: \{currency.exponent} decimal place(s), symbol \{currency.display_symbol()}",
    )
  }
  println("cash rounding:")
  for code in ["CHF", "DKK", "SEK", "USD"] {
    let currency = @moonmoney.Currency::find(code).unwrap()
    let step = @moonmoney.Money::of_minor(currency.cash_increment(), currency)
    let note = if currency.has_cash_rounding() {
      ""
    } else {
      " (no special step)"
    }
    println(
      "  \{code} settles to \{show(step, @format.MoneyStyle::code_first())}\{note}",
    )
  }

  heading("reading amounts from text")
  for text in ["USD 1,234.56", "CA$12.34", "1.234,56 €", "¥1,234"] {
    println("  \{text}  ->  \{read_result(text)}")
  }
  println("  and when the text names no currency, the caller declares one:")
  for text in ["(5.00)", "5.00-", "1.234", "1.2345"] {
    println("  \{text} as USD  ->  \{read_in_result(text, "USD")}")
  }

  heading("why not a float")
  println("  0.1 + 0.2 as a Double is \{0.1 + 0.2}")
  let mut cents = amount(0L)
  for _ in 0..<100 {
    cents = cents.add(amount(1L)) catch {
      error => abort(@moonmoney.MoneyError::message(error))
    }
  }
  println(
    "  100 additions of 0.01 USD are \{show(cents, @format.MoneyStyle::standard())}",
  )

  heading("rounding, per mode")
  let odd = @moonmoney.Money::of_minor(1001L, usd())
  for
    mode in [
      @moonmoney.HalfUp,
      @moonmoney.HalfEven,
      @moonmoney.HalfDown,
      @moonmoney.Up,
      @moonmoney.Down,
      @moonmoney.Ceiling,
      @moonmoney.Floor,
    ] {
    let half = @moonmoney.Money::of_minor(-1001L, usd())
    let positive = odd.div_int64(2L, mode~) catch {
      error => abort(@moonmoney.MoneyError::message(error))
    }
    let negative = half.div_int64(2L, mode~) catch {
      error => abort(@moonmoney.MoneyError::message(error))
    }
    let positive_text = show(positive, @format.MoneyStyle::plain())
    let negative_text = show(negative, @format.MoneyStyle::plain())
    println(
      "  \{mode.label()}: 10.01 -> \{positive_text}, -10.01 -> \{negative_text}",
    )
  }

  heading("splitting a bill without losing a cent")
  let bill = amount(10000L)
  let thirds = bill.allocate(3) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println("  100.00 three ways: \{share_text(thirds)}")
  let weighted = bill.allocate_ratios([3L, 2L, 1L]) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println("  100.00 as 3:2:1:   \{share_text(weighted)}")
  let quartered = amount(9999L).allocate_percents([
    @moonmoney.Percent::of_bp(2500L),
    @moonmoney.Percent::of_bp(2500L),
    @moonmoney.Percent::of_bp(5000L),
  ]) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println("  99.99 as 25/25/50: \{share_text(quartered)}")

  heading("tax")
  let net = amount(10000L)
  let tax_rate = percent("19%")
  let gross = net.with_tax(tax_rate) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println(
    "  net \{show(net, plan_style())} at 19% grosses to \{show(gross, plan_style())}",
  )
  let (back_net, tax) = gross.net_from_gross(tax_rate) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println(
    "  and back: net \{show(back_net, plan_style())}, tax \{show(tax, plan_style())}",
  )
  let lines = net.tax_lines([percent("7%"), percent("19%")]) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  for line in lines {
    println(
      "  at \{line.rate.text()}: tax \{show(line.tax, plan_style())}, gross \{show(line.gross, plan_style())}",
    )
  }

  heading("exchange")
  let eur = @moonmoney.Currency::find("EUR").unwrap()
  let rate_eur = exchange_rate("0.85")
  let converted = amount(10000L).convert(eur, rate_eur) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println("  100.00 USD at 0.85 is \{show(converted, plan_style())}")
  let jpy = @moonmoney.Currency::find("JPY").unwrap()
  let rate_jpy = exchange_rate("150")
  let yen = amount(10000L).convert(jpy, rate_jpy) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  println("  100.00 USD at 150 is \{show(yen, plan_style())}")

  heading("the same amount, written the local way")
  let money = amount(123456L)
  for locale in ["en-US", "de-DE", "fr-FR", "en-IN", "sv-SE"] {
    let style = @format.MoneyStyle::for_locale(locale).unwrap()
    let inr_style = if locale == "en-IN" {
      @format.format(
        @moonmoney.Money::of_minor(
          12345678L,
          @moonmoney.Currency::find("INR").unwrap(),
        ),
        style~,
      ) catch {
        error => abort(@moonmoney.MoneyError::message(error))
      }
    } else {
      show(money, style)
    }
    println("  \{locale}: \{inr_style}")
  }
}

///|
/// `$12.34` with the symbol in front, which reads better in a list than the
/// code-first form.
fn plan_style() -> @format.MoneyStyle {
  @format.MoneyStyle::standard()
}

///|
/// The shares of a split, with their total, so that the invariant is visible.
fn share_text(shares : Array[@moonmoney.Money]) -> String {
  let parts : Array[String] = []
  for share in shares {
    parts.push(show(share, @format.MoneyStyle::plain()))
  }
  let total = @moonmoney.Money::sum(shares, usd()) catch {
    error => abort(@moonmoney.MoneyError::message(error))
  }
  parts.join(" + ") + " = " + show(total, @format.MoneyStyle::plain())
}
