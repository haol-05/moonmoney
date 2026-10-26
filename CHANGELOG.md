# Changelog

## 0.1.2

- **Fixed:** rounding with a negative divisor moved toward zero instead of away
  from it. `div_round(561438828, -2047, HalfEven)` returned `-274272` where the
  nearest integer is `-274274`; the step is now derived from the sign of the
  quotient, which is the sign of the numerator times the sign of the denominator.
  The four directed modes were affected the same way and are fixed with it.
- **Fixed:** `Money::debug_string` printed the literal text `{self.minor}`
  instead of the amount, because one interpolation escape was missing.
- **Added:** a property-test suite over `moonbitlang/core/quickcheck` (allocation
  totals, the rounding neighbourhood, tax reversibility, arithmetic laws,
  identity conversion), a branch-coverage suite for every refusal, and a
  regression test for the negative-divisor rounding.
- **Added:** `moon package` to the continuous integration run, so the zip the
  registry would receive is built on every push.
- **Changed:** three unreachable match arms were removed rather than left as
  untested defensive code; the invariants that made them impossible are recorded
  in comments. The suite is now 89 tests.

## 0.1.1

Documentation release so that the published package matches the repository
exactly: the README carries the Mooncakes link and the quick start shows
`moon add`, and SOURCES.md records how to replace the ISO compilation with the
official SIX list. No API or behaviour change.

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
