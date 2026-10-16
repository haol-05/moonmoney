// The exact rounding primitives every other operation is built on.
//
// Money is stored as an integer number of minor units, so rounding only ever
// happens when an operation is not closed over the integers: a division, a
// percentage, a tax rate or a currency conversion. Those go through
// `big_div_round`, which forms the intermediate in arbitrary precision and
// reports an overflow instead of wrapping.

///|
/// How a value that falls between two minor units is resolved.
///
/// The names are the ones accounting and payment code uses. `HalfUp` is the
/// common commercial default, `HalfEven` is banker's rounding, `Ceiling` and
/// `Floor` are towards positive and negative infinity.
pub(all) enum RoundingMode {
  HalfUp
  HalfDown
  HalfEven
  Up
  Down
  Ceiling
  Floor
} derive(Eq, Debug)

///|
pub fn RoundingMode::label(self : RoundingMode) -> String {
  match self {
    HalfUp => "half-up"
    HalfDown => "half-down"
    HalfEven => "half-even"
    Up => "up"
    Down => "down"
    Ceiling => "ceiling"
    Floor => "floor"
  }
}

///|
let big_two : @bigint.BigInt = @bigint.BigInt::from_int(2)

///|
let big_one : @bigint.BigInt = @bigint.BigInt::from_int(1)

///|
/// Narrows a value that is known to be exact, reporting an overflow rather than
/// truncating when it does not fit.
fn big_to_int64(
  value : @bigint.BigInt,
  operation : String,
) -> Int64 raise MoneyError {
  if value.compare_int64(@int64.MAX_VALUE) > 0 ||
    value.compare_int64(@int64.MIN_VALUE) < 0 {
    raise Overflow(operation)
  }
  value.to_int64()
}

///|
/// Rounds `numerator / denominator` to the nearest integer under `mode`.
///
/// The quotient is computed in arbitrary precision, so large amounts, large
/// rates and large divisors are all handled without an intermediate overflow.
fn big_div_round(
  numerator : @bigint.BigInt,
  denominator : @bigint.BigInt,
  mode : RoundingMode,
) -> Int64 raise MoneyError {
  if denominator.is_zero() {
    raise DivisionByZero
  }
  let quotient = numerator.div(denominator)
  let remainder = numerator.mod(denominator)
  if remainder.is_zero() {
    return big_to_int64(quotient, "division")
  }
  let negative_remainder = remainder.compare_int(0) < 0
  let abs_remainder = if negative_remainder {
    remainder.neg()
  } else {
    remainder
  }
  let negative_denominator = denominator.compare_int(0) < 0
  let abs_denominator = if negative_denominator {
    denominator.neg()
  } else {
    denominator
  }
  let twice_remainder = abs_remainder.mul(big_two)
  let comparison = twice_remainder.compare(abs_denominator)
  let quotient_even = quotient.mod(big_two).is_zero()
  let away_from_zero = match mode {
    HalfUp => comparison >= 0
    HalfDown => comparison > 0
    HalfEven => comparison > 0 || (comparison == 0 && !quotient_even)
    Up => true
    Down => false
    Ceiling => !negative_remainder
    Floor => negative_remainder
  }
  if !away_from_zero {
    return big_to_int64(quotient, "division")
  }
  let bump = if negative_remainder { big_one.neg() } else { big_one }
  big_to_int64(quotient.add(bump), "division")
}

///|
/// Rounds `numerator / denominator` to an integer.
pub fn div_round(
  numerator : Int64,
  denominator : Int64,
  mode : RoundingMode,
) -> Int64 raise MoneyError {
  big_div_round(
    @bigint.BigInt::from_int64(numerator),
    @bigint.BigInt::from_int64(denominator),
    mode,
  )
}

///|
/// Computes `left * right / divisor` exactly and rounds once, at the end.
///
/// This is the shape of every rate application in the library: apply a
/// percentage, add tax, convert a currency. Forming the product in arbitrary
/// precision means an intermediate that does not fit 64 bits cannot silently
/// wrap, and rounding once at the end avoids the double-rounding error of
/// rounding the product before dividing.
pub fn mul_div_round(
  left : Int64,
  right : Int64,
  divisor : Int64,
  mode : RoundingMode,
) -> Int64 raise MoneyError {
  big_div_round(
    @bigint.BigInt::from_int64(left).mul(@bigint.BigInt::from_int64(right)),
    @bigint.BigInt::from_int64(divisor),
    mode,
  )
}

///|
/// Checked addition; `operation` names the caller in the error.
pub fn add_checked(
  left : Int64,
  right : Int64,
  operation : String,
) -> Int64 raise MoneyError {
  if right > 0L && left > @int64.MAX_VALUE - right {
    raise Overflow(operation)
  }
  if right < 0L && left < @int64.MIN_VALUE - right {
    raise Overflow(operation)
  }
  left + right
}

///|
/// Checked subtraction.
pub fn sub_checked(
  left : Int64,
  right : Int64,
  operation : String,
) -> Int64 raise MoneyError {
  if right > 0L && left < @int64.MIN_VALUE + right {
    raise Overflow(operation)
  }
  if right < 0L && left > @int64.MAX_VALUE + right {
    raise Overflow(operation)
  }
  left - right
}

///|
/// Checked multiplication.
pub fn mul_checked(
  left : Int64,
  right : Int64,
  operation : String,
) -> Int64 raise MoneyError {
  if left == 0L || right == 0L {
    return 0L
  }
  big_to_int64(
    @bigint.BigInt::from_int64(left).mul(@bigint.BigInt::from_int64(right)),
    operation,
  )
}
