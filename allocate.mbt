// Splitting an amount without losing or inventing a minor unit.
//
// Splitting 100.00 three ways is the classic broken case: a naive loop hands out
// 33.33, 33.33 and 33.33 and leaves a cent in the air. The largest-remainder
// method used here assigns every part its integer share first and then gives the
// remaining minor units to the parts with the largest exact remainder, so the
// parts always add back up to the original amount and no two parts differ by
// more than one minor unit.

///|
/// Orders indices by descending remainder, ties by ascending index, so that the
/// result does not depend on how the input happened to be ordered.
fn order_by_remainder(remainders : Array[@bigint.BigInt]) -> Array[Int32] {
  let order : Array[Int32] = []
  let count = remainders.length()
  for index in 0..<count {
    order.push(index)
  }
  let mut position = 1
  while position < count {
    let current = order[position]
    let mut scan = position - 1
    while scan >= 0 && remainders[order[scan]].compare(remainders[current]) < 0 {
      order[scan + 1] = order[scan]
      scan -= 1
    }
    order[scan + 1] = current
    position += 1
  }
  order
}

///|
/// Distributes a non-negative magnitude over non-negative weights.
fn allocate_magnitude(
  magnitude : Int64,
  weights : Array[Int64],
) -> Array[Int64] raise MoneyError {
  let count = weights.length()
  if count == 0 {
    raise EmptyAllocation("an allocation")
  }
  let mut total_weight = 0L
  for weight in weights {
    if weight < 0L {
      raise InvalidAmount(weight.to_string(), "a weight cannot be negative")
    }
    total_weight = add_checked(total_weight, weight, "sum of weights")
  }
  if total_weight == 0L {
    raise EmptyRatio
  }
  let numerator = @bigint.BigInt::from_int64(magnitude)
  let denominator = @bigint.BigInt::from_int64(total_weight)
  let parts : Array[Int64] = []
  let remainders : Array[@bigint.BigInt] = []
  let mut assigned = 0L
  for weight in weights {
    let exact = numerator.mul(@bigint.BigInt::from_int64(weight))
    let share = big_to_int64(exact.div(denominator), "allocation")
    parts.push(share)
    remainders.push(exact.mod(denominator))
    assigned = add_checked(assigned, share, "allocation")
  }
  let leftover = sub_checked(magnitude, assigned, "allocation")
  let order = order_by_remainder(remainders)
  let mut extra = leftover
  let mut position = 0
  while extra > 0L && position < count {
    let index = order[position]
    parts[index] = add_checked(parts[index], 1L, "allocation")
    extra -= 1L
    position += 1
  }
  parts
}

///|
/// Splits the amount by weights, keeping the total exact.
///
/// The weights are relative, so `[1, 1, 1]` splits three ways and
/// `[3, 1]` gives three quarters to the first part. A negative weight is
/// refused rather than interpreted.
pub fn Money::allocate_ratios(
  self : Money,
  weights : Array[Int64],
) -> Array[Money] raise MoneyError {
  if self.minor == @int64.MIN_VALUE {
    raise Overflow("allocation of the smallest representable amount")
  }
  let negative = self.minor < 0L
  let magnitude = if negative { 0L - self.minor } else { self.minor }
  let parts = allocate_magnitude(magnitude, weights)
  let result : Array[Money] = []
  for part in parts {
    let minor = if negative { 0L - part } else { part }
    result.push({ minor, currency: self.currency, })
  }
  result
}

///|
/// Splits the amount into `parts` equal shares, handing the minor units that
/// do not divide evenly to the earliest parts.
///
/// 10.00 into 3 gives 3.34, 3.33, 3.33.
pub fn Money::allocate(
  self : Money,
  parts : Int32,
) -> Array[Money] raise MoneyError {
  if parts <= 0 {
    raise EmptyAllocation("an allocation")
  }
  let weights : Array[Int64] = []
  for _ in 0..<parts {
    weights.push(1L)
  }
  self.allocate_ratios(weights)
}

///|
/// Splits the amount in proportion to percentages.
///
/// The percentages are weights, not a required sum: `[25, 25, 25]` leaves the
/// final quarter to be assigned to the largest remainders rather than dropped.
/// This is what an expense splitter and a revenue share calculation need.
pub fn Money::allocate_percents(
  self : Money,
  percents : Array[Percent],
) -> Array[Money] raise MoneyError {
  let weights : Array[Int64] = []
  for percent in percents {
    weights.push(percent.bp())
  }
  self.allocate_ratios(weights)
}
