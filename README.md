# MoonMoney

**Exact money and currency arithmetic for MoonBit.** Amounts are integers in the
smallest unit a currency defines, so a cent is never lost to a float; splitting
an amount always adds back up; tax, cash rounding and currency conversion each
round exactly once. The ISO 4217 registry, the parser and twenty locale formats
come with it.

```text
$ moon run cmd/main -- tax 10000 USD 19%
  net:   $100.00
  rate:  19%
  tax:   $19.00
  gross: $119.00

$ moon run cmd/main -- split 10000 USD 3
  1: $33.34
  2: $33.33
  3: $33.33
  total: $100.00

$ moon run cmd/main -- parse "CA$12.34"
CAD 12.34
  minor units: 1234
  currency:    CAD (Canadian Dollar)
```

The point is the third line of the first block and the last line of the second.
A naive implementation gives `100.00 / 3` as `33.3333...` three times and loses
the last cent, or stores `119.00` as `118.99999999999999`. MoonMoney stores
`100.00` as the integer `10000` and `19%` as the integer `1900` basis points, so
both answers are exact by construction rather than by luck.

## Why

The MoonBit ecosystem already has arbitrary-precision arithmetic
([`moonbit-community/decimal`](https://mooncakes.io/docs/moonbit-community/decimal),
[`Luna-Flow/floating`](https://mooncakes.io/docs/Luna-Flow/floating)) and several
date and schedule libraries. What it did not have, as of 2026-10-16, was a money
domain: a registry of ISO 4217 currencies with their minor units, an amount type
that cannot be added to an amount in another currency, allocation that preserves
the total, and the small set of operations that billing, expense splitting and
reporting actually need.

MoonMoney is not a decimal arithmetic library. It does not do arbitrary-precision
general arithmetic and it does not wrap another one; it is the layer above, and
that is the layer where a cent goes missing.

## Requirements

- The [MoonBit toolchain](https://www.moonbitlang.com/download/), **`moonc`
  0.10.14 or newer** — the floor the OSC acceptance rules set. This repository is
  developed, formatted and verified with `moon 0.1.20261012` / `moonc v0.10.15`,
  which is the release continuous integration installs as well, so `moon fmt`
  and `moon info` reproduce the committed files byte for byte.
- Nothing outside `moonbitlang/core` is needed to build, test or run the library,
  on `wasm`, `wasm-gc` and `js`.
- A C toolchain for `--target native`: the toolchain's Windows native backend
  wants MSVC Build Tools (`cl.exe` or `clang-cl.exe`), so a Windows machine with
  only mingw cannot build that one target. CI covers all four targets on Linux.
- Node.js only if you want to regenerate the currency table.

## Quick start

```sh
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
moon run examples/demo                  # a self-contained tour, no arguments
moon run cmd/main -- parse "USD 1,234.56"
```

`examples/demo` prints each section of the library in turn and ends with the same
amount written five ways. Its output is the fastest way to see what the library
does and what it refuses.

## What it does

| Area | Details |
| --- | --- |
| Registry | 165 ISO 4217 currencies with a defined minor unit: alphabetic and numeric code, minor units, CLDR display digits, cash digits and cash step, English name, symbol. `Currency::custom` covers everything else. |
| Amounts | `Money` is `{ minor: Int64, currency: Currency }`. Build from minor units, whole units, or units plus a fraction; read back whole units and the fraction; compare, negate, take the absolute value. |
| Arithmetic | Add, subtract, multiply by a whole number, divide with a rounding mode. Combining two currencies is an error, not a conversion. Overflow is reported, never wrapped. |
| Rounding | `HalfUp`, `HalfDown`, `HalfEven`, `Up`, `Down`, `Ceiling`, `Floor`, plus rounding to an arbitrary step and to a currency's own cash step (CHF to 0.05, DKK to 0.50). |
| Percentages | `Percent` is an exact number of basis points. Apply a percentage, add it (net to gross) or subtract it (a discount). |
| Allocation | Split an amount into equal, weighted or percentage shares with the largest-remainder method: the shares always sum to the original and no two differ by more than one minor unit. |
| Tax | Tax on a net amount, the net recovered from a gross amount, and one line per rate. |
| Exchange | A rate is an exact scaled integer; conversion multiplies in arbitrary precision and rounds once. |
| Parsing | Codes and disambiguated symbols, both separator conventions, signs, trailing signs, accounting parentheses. |
| Formatting | Symbol, code or bare; grouping by threes or the Indian 3-2 pattern; twenty locale presets; minus, parentheses or trailing minus. |

## Using it

```moonbit
// A net invoice line and its tax. Every call that can fail says so in its type.
fn invoice_line(net_minor : Int64, rate_text : String) -> String raise @moonmoney.MoneyError {
  let usd = @moonmoney.Currency::find("USD").unwrap()
  let net = @moonmoney.Money::of_minor(net_minor, usd)
  let rate = @moonmoney.Percent::parse(rate_text)
  let gross = net.with_tax(rate)
  "\{@format.format(net)} + \{rate.text()} = \{@format.format(gross)}"
}
```

```moonbit
// Splitting a bill without losing a cent.
let total = @moonmoney.Money::of_minor(10000L, usd)   // USD 100.00
let shares = total.allocate(3)                        // [33.34, 33.33, 33.33]
let weighted = total.allocate_ratios([3L, 2L, 1L])    // [50.00, 33.33, 16.67]
```

```moonbit
// Reading amounts that were written the way people write them.
let a = @parse.amount("USD 1,234.56")     // USD 1234.56
let b = @parse.amount("1.234,56 €")       // EUR 1234.56, the continental reading
let c = @parse.amount("CA$12.34")         // CAD 12.34
let d = @parse.amount_in("(5.00)", usd)   // -USD 5.00, accounting negative
```

## Reading an amount

The parser is strict where guessing would cost money.

- **The currency has to be known.** Either the text names it (`USD 12.34`,
  `CA$12.34`, `€12.34`) or the caller supplies it with `amount_in`. A symbol is
  only matched as a whole token and the symbols are the disambiguated CLDR ones,
  so `A$` is the Australian dollar, `CA$` the Canadian one and a bare `$` is the
  US dollar — the only currency CLDR gives that symbol. `Total: 12.34` is
  reported as unknown rather than parsed as if `Total:` were a currency.
- **The decimal mark is found by rule.** One to `exponent` digits after the last
  mark make it the decimal mark, so `1,234.56` and `1.234,56` both read as one
  thousand two hundred thirty four point five six. More than that is still a
  decimal mark unless exactly three digits follow, because three is a grouping
  group: `1,235` is 1235, while `1.2345` is a fraction of four places. Grouping
  that is not in threes is refused.
- **Precision that does not fit is refused.** `amount_in("USD 1.2345")` reports
  an error. `amount_in_rounded` rounds once under a mode you name instead.

## Writing an amount

```moonbit
@format.format(money)                                  // $1,234.56
@format.format(money, style=@format.MoneyStyle::code_first())   // USD 1,234.56
@format.format(money, style=@format.MoneyStyle::plain())        // 1234.56
@format.format(money, style=@format.MoneyStyle::accounting())   // ($1,234.56) when negative
@format.MoneyStyle::for_locale("de-DE")                // 1.234,56 $
@format.MoneyStyle::for_locale("en-IN")                // ₹1,23,456.78
```

The number of decimal places follows the currency unless a style overrides it.
Formatting to fewer places than the currency holds rounds half to even, once;
asking for more pads with zeros and never invents precision.

## Honest limits

- **No exchange rates are fetched.** Conversion needs a rate you supply, which
  keeps the result deterministic and the library offline. There is no rate feed,
  no historical rate and no triangulation.
- **No decimal arithmetic.** The library is fixed point. Amounts are bounded by
  `Int64` minor units; a result that does not fit is reported as an overflow
  rather than promoted to a bigger type or a float.
- **No locale database.** Twenty layouts ship in the source. An unknown tag
  returns `None` rather than a guess.
- **Nothing is validated against a payment network.** The ISO 4217 table is
  reference data, not a statement about what a bank will accept.
- **The ISO data's underlying licence is unclear.** See
  [SOURCES.md](SOURCES.md); that file records the one provenance point a reviewer
  should confirm, and the generator is written so the source can be swapped
  without changing the output format.
- **Not yet published to Mooncakes.** The module is `haol-05/moonmoney`.

## Reproducing the currency table

```sh
node tools/generate_currency_table.mjs
```

The script reads the two data sets over jsDelivr, reconciles them and rewrites
`currency_table.mbt` in the canonical `moon fmt` form, so the generated file is
byte-identical to what the formatter would produce and `moon fmt` is a no-op on
it. Running the script twice produces a byte-identical file. The provenance of every field is recorded in
[SOURCES.md](SOURCES.md) and repeated in the header of the generated file.

## Layout

```text
moonmoney/            the core: Currency and its table, Money, rounding,
                      percentages, allocation, tax, exchange
parse/                text to Money
format/               Money to text, with the locale presets
cmd/main/             the command line
examples/demo/        a runnable tour
tools/                the table generator
```

## Licence

Apache-2.0; see [LICENSE](LICENSE). The data sets and their licences are recorded
in [SOURCES.md](SOURCES.md).
