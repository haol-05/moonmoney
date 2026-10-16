// The MoonMoney command line.
//
//   moon run cmd/main -- parse "USD 1,234.56"
//   moon run cmd/main -- format 123456 USD de-DE
//   moon run cmd/main -- split 10000 USD 3
//   moon run cmd/main -- tax 10000 USD 19%
//   moon run cmd/main -- convert 10000 USD EUR 0.85
//   moon run cmd/main -- currencies C
//
// Amounts on the command line are given in minor units, so 12.34 USD is 1234.
// Every argument is taken literally; there is no configuration file and no
// network access.

///|
const USAGE : String =
  #|moonmoney - exact money arithmetic on ISO 4217 currencies
  #|
  #|usage:
  #|  moonmoney parse <text>
  #|  moonmoney format <minor> <CODE> [locale|plain|code|accounting]
  #|  moonmoney split <minor> <CODE> <parts>
  #|  moonmoney split <minor> <CODE> weights <w1> <w2> ...
  #|  moonmoney tax <minor> <CODE> <rate%>
  #|  moonmoney convert <minor> <FROM> <TO> <rate>
  #|  moonmoney currencies [code-prefix]
  #|  moonmoney version
  #|
  #|notes:
  #|  <minor> is the amount in minor units: 12.34 USD is 1234, 500 yen is 500.
  #|  A rate is a decimal such as 0.85 or 150.
  #|
  #|examples:
  #|  moonmoney parse "CA$12.34"
  #|  moonmoney format 123456 USD en-IN
  #|  moonmoney split 10000 USD 3
  #|  moonmoney split 10000 USD weights 3 2 1
  #|  moonmoney tax 10000 USD 19%
  #|  moonmoney convert 10000 USD EUR 0.85
  #|

///|
fn currency_of(code : String) -> @moonmoney.Currency {
  match @moonmoney.Currency::find(code) {
    Some(currency) => currency
    None => abort("moonmoney: unknown currency \{code}")
  }
}

///|
fn integer_of(text : String) -> Int64 {
  @string.parse_int64(text) catch {
    _ => abort("moonmoney: \{text} is not a whole number")
  }
}

///|
fn rate_of(text : String) -> @moonmoney.Rate {
  @moonmoney.Rate::parse(text) catch {
    error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
  }
}

///|
fn percent_of(text : String) -> @moonmoney.Percent {
  @moonmoney.Percent::parse(text) catch {
    error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
  }
}

///|
fn render(money : @moonmoney.Money, style : @format.MoneyStyle) -> String {
  @format.format(money, style~) catch {
    error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
  }
}

///|
fn style_named(name : String) -> @format.MoneyStyle {
  match name {
    "plain" => @format.MoneyStyle::plain()
    "code" => @format.MoneyStyle::code_first()
    "accounting" => @format.MoneyStyle::accounting()
    _ =>
      match @format.MoneyStyle::for_locale(name) {
        Some(style) => style
        None => abort("moonmoney: no style or locale named \{name}")
      }
  }
}

///|
fn main {
  let argv = @env.args()
  let args : Array[String] = []
  for index in 1..<argv.length() {
    args.push(argv[index])
  }
  if args.length() == 0 {
    println(USAGE)
    return
  }
  match args[0] {
    "parse" => {
      if args.length() != 2 {
        abort("moonmoney: parse takes one amount")
      }
      let money = @parse.amount(args[1]) catch {
        error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
      }
      println(render(money, @format.MoneyStyle::code_first()))
      println("  minor units: \{money.minor}")
      println("  currency:    \{money.currency.label()}")
    }
    "format" => {
      if args.length() < 3 || args.length() > 4 {
        abort("moonmoney: format takes <minor> <CODE> [locale]")
      }
      let money = @moonmoney.Money::of_minor(
        integer_of(args[1]),
        currency_of(args[2]),
      )
      let style = if args.length() == 4 {
        style_named(args[3])
      } else {
        @format.MoneyStyle::standard()
      }
      println(render(money, style))
    }
    "split" => {
      let currency = if args.length() >= 3 {
        currency_of(args[2])
      } else {
        abort("moonmoney: split takes <minor> <CODE> ...")
      }
      if args.length() < 4 {
        abort("moonmoney: split takes <minor> <CODE> <parts>")
      }
      let money = @moonmoney.Money::of_minor(integer_of(args[1]), currency)
      let shares = if args[3] == "weights" {
        let weights : Array[Int64] = []
        for index in 4..<args.length() {
          weights.push(integer_of(args[index]))
        }
        money.allocate_ratios(weights) catch {
          error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
        }
      } else {
        money.allocate(integer_of(args[3]).to_int()) catch {
          error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
        }
      }
      let total = @moonmoney.Money::sum(shares, currency) catch {
        error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
      }
      for index in 0..<shares.length() {
        println(
          "  \{index + 1}: \{render(shares[index], @format.MoneyStyle::standard())}",
        )
      }
      println("  total: \{render(total, @format.MoneyStyle::standard())}")
    }
    "tax" => {
      if args.length() != 4 {
        abort("moonmoney: tax takes <minor> <CODE> <rate>")
      }
      let net = @moonmoney.Money::of_minor(
        integer_of(args[1]),
        currency_of(args[2]),
      )
      let rate = percent_of(args[3])
      let tax = net.tax_on(rate) catch {
        error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
      }
      let gross = net.with_tax(rate) catch {
        error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
      }
      println("  net:   \{render(net, @format.MoneyStyle::standard())}")
      println("  rate:  \{rate.text()}")
      println("  tax:   \{render(tax, @format.MoneyStyle::standard())}")
      println("  gross: \{render(gross, @format.MoneyStyle::standard())}")
    }
    "convert" => {
      if args.length() != 5 {
        abort("moonmoney: convert takes <minor> <FROM> <TO> <rate>")
      }
      let money = @moonmoney.Money::of_minor(
        integer_of(args[1]),
        currency_of(args[2]),
      )
      let converted = money.convert(currency_of(args[3]), rate_of(args[4])) catch {
        error => abort("moonmoney: " + @moonmoney.MoneyError::message(error))
      }
      println(
        "  \{render(money, @format.MoneyStyle::code_first())} at \{args[4]} is \{render(converted, @format.MoneyStyle::code_first())}",
      )
    }
    "currencies" => {
      let prefix = if args.length() >= 2 { args[1].to_upper() } else { "" }
      let mut shown = 0
      for currency in @moonmoney.Currency::all() {
        if prefix == "" || currency.code.has_prefix(prefix) {
          println(
            "  \{currency.code}  \{currency.exponent} dp  \{currency.display_symbol()}  \{currency.name}",
          )
          shown += 1
        }
      }
      println("  \{shown} of \{@moonmoney.Currency::count()}")
    }
    "version" => println("moonmoney 0.1.0")
    "help" => println(USAGE)
    _ => {
      println(USAGE)
      abort("moonmoney: unknown command \{args[0]}")
    }
  }
}
