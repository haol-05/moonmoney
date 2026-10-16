// Tax, gross and net.
//
// Two questions cover almost every invoice: what tax does this net amount
// attract, and what was the net behind this gross amount. Both are answered
// with an exact rate and a single rounding step.

///|
/// The tax an amount attracts at a rate.
pub fn Money::tax_on(
  self : Money,
  rate : Percent,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  self.percent(rate, mode~)
}

///|
/// The net amount plus its tax.
pub fn Money::with_tax(
  self : Money,
  rate : Percent,
  mode? : RoundingMode = HalfUp,
) -> Money raise MoneyError {
  self.add_percent(rate, mode~)
}

///|
/// One rate's worth of an invoice: the net it applied to, the tax it produced
/// and the gross that results.
pub(all) struct TaxLine {
  rate : Percent
  net : Money
  tax : Money
  gross : Money
} derive(Debug)

///|
pub extend TaxLine with @debug.Debug::{to_repr}

///|
/// Recovers the net and the tax from a tax-inclusive amount.
///
/// The tax is the difference between the gross and the recovered net, so the
/// two parts always add back up to the gross. A rate of -100% or less cannot be
/// reversed and is refused.
pub fn Money::net_from_gross(
  gross : Money,
  rate : Percent,
  mode? : RoundingMode = HalfUp,
) -> (Money, Money) raise MoneyError {
  let denominator = add_checked(10000L, rate.bp(), "tax rate")
  if denominator <= 0L {
    raise InvalidAmount(
      rate.text(),
      "a rate of -100% or less cannot be reversed",
    )
  }
  let net_minor = mul_div_round(gross.minor, 10000L, denominator, mode)
  let net = { minor: net_minor, currency: gross.currency }
  (net, gross.sub(net))
}

///|
/// One line per rate, each rate applied to the same net amount.
///
/// This models the taxes that stack on a single net -- a sales tax plus a local
/// levy, say -- rather than a basket of differently taxed items. The gross of
/// each line is the net plus that line's tax, so the lines can be printed
/// directly.
pub fn Money::tax_lines(
  self : Money,
  rates : Array[Percent],
  mode? : RoundingMode = HalfUp,
) -> Array[TaxLine] raise MoneyError {
  let lines : Array[TaxLine] = []
  for rate in rates {
    let tax = self.tax_on(rate, mode~)
    lines.push({ rate, net: self, tax, gross: self.add(tax) })
  }
  lines
}
