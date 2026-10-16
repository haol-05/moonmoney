# Changelog

## 0.1.0

First release.

- ISO 4217 registry with 165 currencies: alphabetic and numeric code, minor
  units, CLDR display digits, cash digits and cash step, English name and symbol.
- `Money`: exact amounts in minor units, with construction from minor units,
  whole units or units plus a fraction; arithmetic and comparison that refuse to
  mix currencies.
- Seven rounding modes with one exact rounding step per operation, and checked
  arithmetic that reports an overflow instead of wrapping.
- `Percent` in basis points, applied to an amount, added, subtracted or
  recovered from a rate.
- Allocation that always adds back up: equal shares, weighted shares and
  percentage shares, using the largest-remainder method.
- Tax: tax on a net amount, net recovered from a gross amount, and one line per
  rate.
- Exchange: a rate as an exact scaled integer, conversion with a single rounding
  step, and inversion to twelve places.
- Parsing: codes and disambiguated symbols, grouping and decimal marks in both
  conventions, signs, accounting parentheses, and refusal of more precision than
  the currency holds unless a rounding mode is given.
- Formatting: symbol, code or bare; grouping by threes or the Indian 3-2
  pattern; twenty locale presets; three ways of marking a negative.
- A runnable tour (`examples/demo`) and a command line (`cmd/main`).
