// Property tests for the invariants the library promises.
//
// The example-based tests next to this file pin down specific values; these
// check the statements that have to hold for *every* input: an allocation adds
// back up, rounding lands on a nearest integer, tax and its reverse agree, and
// arithmetic is commutative and invertible. QuickCheck generates the inputs and
// shrinks a failure to a small counterexample.
//
// Generated values are folded into a magnitude the property can reason about, so
// a failure means the library is wrong rather than the test overflowing.

///|
/// Folds a generated integer into `(-limit, limit)` without overflowing on
/// `Int64::min_value`.
fn bounded(value : Int64, limit : Int64) -> Int64 {
  value % limit
}

///|
/// A weight in `0..=9`.
fn weight_of(value : Int64) -> Int64 {
  let reduced = value % 10L
  if reduced < 0L {
    0L - reduced
  } else {
    reduced
  }
}

///|
fn weights_of(raw : Array[Int64]) -> Array[Int64] {
  let out : Array[Int64] = []
  for value in raw {
    out.push(weight_of(value))
  }
  out
}

///|
fn sum_weights(weights : Array[Int64]) -> Int64 {
  let mut total = 0L
  for weight in weights {
    total = total + weight
  }
  total
}

///|
/// The range a property uses: small enough that no intermediate in the library
/// can overflow, wide enough to cross the interesting boundaries.
const PROP_LIMIT : Int64 = 1000000000L

///|
test "quickcheck: a weighted allocation always adds back up" {
  @quickcheck.check(
    (input : (Int64, Array[Int64])) => {
      let (raw_total, raw_weights) = input
      let weights = weights_of(raw_weights)
      if weights.length() == 0 || sum_weights(weights) == 0L {
        return true
      }
      let total = bounded(raw_total, PROP_LIMIT)
      let parts = @moonmoney.Money::of_minor(total, usd()).allocate_ratios(
        weights,
      ) catch {
        _ => return false
      }
      if parts.length() != weights.length() {
        return false
      }
      let mut sum = 0L
      for part in parts {
        sum = sum + part.minor
      }
      sum == total
    },
    count=300,
  )
}

///|
test "quickcheck: an equal allocation always adds back up" {
  @quickcheck.check(
    (input : (Int64, Int32)) => {
      let (raw_total, raw_parts) = input
      let magnitude = if raw_parts < 0 { -raw_parts } else { raw_parts }
      let count = magnitude % 64 + 1
      let total = bounded(raw_total, PROP_LIMIT)
      let shares = @moonmoney.Money::of_minor(total, usd()).allocate(count) catch {
        _ => return false
      }
      if shares.length() != count {
        return false
      }
      let mut sum = 0L
      for share in shares {
        sum = sum + share.minor
      }
      sum == total
    },
    count=300,
  )
}

///|
test "quickcheck: an equal split spreads the remainder over at most one unit" {
  @quickcheck.check(
    (input : (Int64, Int32)) => {
      let (raw_total, raw_parts) = input
      let magnitude = if raw_parts < 0 { -raw_parts } else { raw_parts }
      let count = magnitude % 64 + 1
      let total = bounded(raw_total, PROP_LIMIT)
      let parts = @moonmoney.Money::of_minor(total, usd()).allocate(count) catch {
        _ => return false
      }
      if parts.length() == 0 {
        return false
      }
      let mut low = parts[0].minor
      let mut high = parts[0].minor
      for part in parts {
        if part.minor < low {
          low = part.minor
        }
        if part.minor > high {
          high = part.minor
        }
      }
      high - low <= 1L
    },
    count=300,
  )
}

///|
test "quickcheck: half-even rounding lands on a nearest integer" {
  @quickcheck.check(
    (input : (Int64, Int64)) => {
      let (raw_numerator, raw_denominator) = input
      let denominator = bounded(raw_denominator, 65536L)
      if denominator == 0L {
        return true
      }
      let numerator = bounded(raw_numerator, PROP_LIMIT)
      let quotient = @moonmoney.div_round(
        numerator,
        denominator,
        @moonmoney.HalfEven,
      ) catch {
        _ => return false
      }
      let error = numerator - quotient * denominator
      let magnitude_error = if error < 0L { 0L - error } else { error }
      let magnitude_denominator = if denominator < 0L {
        0L - denominator
      } else {
        denominator
      }
      // |n - q*d| <= |d| / 2, written without a division so that an exact
      // half-way tie (equality) is included.
      magnitude_error * 2L <= magnitude_denominator
    },
    count=400,
  )
}

///|
test "quickcheck: the directed modes bracket the exact quotient" {
  @quickcheck.check(
    (input : (Int64, Int64)) => {
      let (raw_numerator, raw_denominator) = input
      let denominator = bounded(raw_denominator, 65536L)
      if denominator <= 0L {
        return true
      }
      let numerator = bounded(raw_numerator, PROP_LIMIT)
      let floor = @moonmoney.div_round(numerator, denominator, @moonmoney.Floor) catch {
        _ => return false
      }
      let down = @moonmoney.div_round(numerator, denominator, @moonmoney.Down) catch {
        _ => return false
      }
      let up = @moonmoney.div_round(numerator, denominator, @moonmoney.Up) catch {
        _ => return false
      }
      let ceiling = @moonmoney.div_round(
        numerator,
        denominator,
        @moonmoney.Ceiling,
      ) catch {
        _ => return false
      }
      // floor <= exact <= ceiling, with truncation and the away-from-zero mode
      // inside those bounds.
      floor <= down && down <= ceiling && up <= ceiling && floor <= up
    },
    count=400,
  )
}

///|
test "quickcheck: tax on a net amount and the reverse agree" {
  @quickcheck.check(
    (input : (Int64, Int64)) => {
      let (raw_net, raw_rate) = input
      let net_minor = bounded(raw_net, PROP_LIMIT)
      let rate_magnitude = bounded(raw_rate, 10000L)
      let magnitude = if rate_magnitude < 0L {
        0L - rate_magnitude
      } else {
        rate_magnitude
      }
      let rate = @moonmoney.Percent::of_bp(magnitude)
      let net = @moonmoney.Money::of_minor(net_minor, usd())
      let tax = net.tax_on(rate) catch { _ => return false }
      let gross = net.add(tax) catch { _ => return false }
      let (recovered_net, recovered_tax) = gross.net_from_gross(rate) catch {
        _ => return false
      }
      // The two parts of the reverse always add back up to the gross.
      let rebuilt = recovered_net.add(recovered_tax) catch { _ => return false }
      if rebuilt.minor != gross.minor {
        return false
      }
      // At a zero rate the net comes back unchanged.
      if magnitude == 0L {
        return recovered_net.minor == net_minor
      }
      true
    },
    count=300,
  )
}

///|
test "quickcheck: adding then subtracting recovers the amount" {
  @quickcheck.check(
    (input : (Int64, Int64)) => {
      let (raw_left, raw_right) = input
      let left = bounded(raw_left, PROP_LIMIT)
      let right = bounded(raw_right, PROP_LIMIT)
      let a = @moonmoney.Money::of_minor(left, usd())
      let b = @moonmoney.Money::of_minor(right, usd())
      let sum = a.add(b) catch { _ => return false }
      let back = sum.sub(b) catch { _ => return false }
      let mirrored = b.add(a) catch { _ => return false }
      back.minor == left && sum.minor == mirrored.minor
    },
    count=400,
  )
}

///|
test "quickcheck: converting at a unit rate is the identity" {
  @quickcheck.check(
    (raw_amount : Int64) => {
      let minor = bounded(raw_amount, PROP_LIMIT)
      let one = @moonmoney.Rate::of_scaled(1000000L, 6).unwrap()
      let eur = @moonmoney.Currency::find("EUR").unwrap()
      let converted = @moonmoney.Money::of_minor(minor, usd()).convert(eur, one) catch {
        _ => return false
      }
      converted.minor == minor
    },
    count=200,
  )
}

///|
test "quickcheck: a whole-unit amount survives a currency with no minor unit" {
  @quickcheck.check(
    (raw_amount : Int64) => {
      // A rate of 100 also converts cents to yen one for one, so a whole number
      // of dollars crosses to yen and back without losing a minor unit.
      let minor = bounded(raw_amount, 10000000L) * 100L
      let hundred = @moonmoney.Rate::of_scaled(100L, 0).unwrap()
      let yen = @moonmoney.Currency::find("JPY").unwrap()
      let source = @moonmoney.Money::of_minor(minor, usd())
      let converted = source.convert(yen, hundred) catch { _ => return false }
      if converted.minor != minor {
        return false
      }
      // The way back needs the reciprocal rate: 0.01 dollars per yen.
      let penny = @moonmoney.Rate::of_scaled(1L, 2).unwrap()
      let back = converted.convert(usd(), penny) catch { _ => return false }
      back.minor == minor
    },
    count=200,
  )
}
