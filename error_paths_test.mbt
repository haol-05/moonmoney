// Branch coverage for the paths a caller only reaches on bad or unusual input.
//
// The behaviour tests next to this file check what the library computes; these
// check what it *refuses*, and that every refusal carries a message. They exist
// because an error path that has never run is an error path nobody has read.

///|
test "amount accessors, including the zero and the empty sign" {
  let zero = @moonmoney.Money::of_minor(0L, usd())
  assert_eq(zero.sign(), 0)
  assert_eq(zero.is_zero(), true)
  assert_eq(amount(5L).is_positive(), true)
  assert_eq(amount(5L).is_negative(), false)
  assert_eq(amount(-5L).is_positive(), false)
  assert_eq(amount(-5L).is_negative(), true)
  assert_eq(amount(1234L).mul(3).minor, 3702L)
  assert_eq(amount(1000L).div(8).minor, 125L)
  assert_eq(amount(1000L).div(8, mode=@moonmoney.HalfEven).minor, 125L)
  assert_eq(amount(1234L).debug_string(), "1234 USD")
  assert_eq(zero.debug_string(), "0 USD")
}

///|
test "amount equality looks at the number and the currency code" {
  assert_true(amount(1L) == amount(1L))
  assert_true(amount(1L) != amount(2L))
  assert_true(amount(1L) != yen(1L))
}

///|
test "minimum and maximum return the other amount when it wins" {
  assert_eq(amount(100L).min(amount(200L)).minor, 100L)
  assert_eq(amount(200L).min(amount(100L)).minor, 100L)
  assert_eq(amount(100L).max(amount(200L)).minor, 200L)
  assert_eq(amount(200L).max(amount(100L)).minor, 200L)
}

///|
test "rounding to a step of zero is refused" {
  let mut raised = false
  let _ = amount(100L).round_to(0L, mode=@moonmoney.HalfUp) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      raised = true
      amount(0L)
    }
    _ => amount(0L)
  }
  assert_eq(raised, true)
}

///|
test "percent accessors" {
  assert_eq(@moonmoney.Percent::zero().is_zero(), true)
  assert_eq(@moonmoney.Percent::of_whole(8L).is_zero(), false)
  // A fraction below ten keeps its leading zero.
  assert_eq(@moonmoney.Percent::of_bp(805L).text(), "8.05%")
  assert_eq(@moonmoney.Percent::of_bp(5L).text(), "0.05%")
  assert_eq(@moonmoney.Percent::of_bp(0L).text(), "0%")
}

///|
test "percent parsing accepts the readable forms and refuses the rest" {
  assert_eq(rate("%8").bp(), 800L)
  assert_eq(rate(".5").bp(), 50L)
  assert_eq(rate("+8.5").bp(), 850L)
  let mut empty = false
  let _ = @moonmoney.Percent::parse("") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      empty = true
      @moonmoney.Percent::zero()
    }
    _ => @moonmoney.Percent::zero()
  }
  assert_eq(empty, true)
  let mut sign_only = false
  let _ = @moonmoney.Percent::parse("-%") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      sign_only = true
      @moonmoney.Percent::zero()
    }
    _ => @moonmoney.Percent::zero()
  }
  assert_eq(sign_only, true)
  let mut no_digits = false
  let _ = @moonmoney.Percent::parse(".") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      no_digits = true
      @moonmoney.Percent::zero()
    }
    _ => @moonmoney.Percent::zero()
  }
  assert_eq(no_digits, true)
  let mut not_a_number = false
  let _ = @moonmoney.Percent::parse("abc%") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      not_a_number = true
      @moonmoney.Percent::zero()
    }
    _ => @moonmoney.Percent::zero()
  }
  assert_eq(not_a_number, true)
}

///|
test "rate parsing covers the integer and half-written forms" {
  assert_eq(exchange_rate("100").scaled, 100L)
  assert_eq(exchange_rate("100").scale, 0)
  assert_eq(exchange_rate(".5").scaled, 5L)
  assert_eq(exchange_rate(".5").scale, 1)
  assert_eq(exchange_rate("1.").scaled, 1L)
  assert_eq(exchange_rate("1.").scale, 0)
  assert_true(@moonmoney.Rate::of_scaled(1L, 19) is None)
  let mut empty = false
  let _ = @moonmoney.Rate::parse("") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      empty = true
      exchange_rate("1")
    }
    _ => exchange_rate("1")
  }
  assert_eq(empty, true)
  let mut too_precise = false
  let _ = @moonmoney.Rate::parse("1.1234567890") catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      too_precise = true
      exchange_rate("1")
    }
    _ => exchange_rate("1")
  }
  assert_eq(too_precise, true)
}

///|
test "a rate of zero cannot be inverted" {
  let zero = @moonmoney.Rate::of_scaled(0L, 2).unwrap()
  let mut raised = false
  let _ = zero.inverse() catch {
    @moonmoney.MoneyError::DivisionByZero => {
      raised = true
      zero
    }
    _ => zero
  }
  assert_eq(raised, true)
}

///|
test "a hand-built rate with an impossible scale is refused, not wrapped" {
  // The fields are public, so a caller can build a Rate that the constructors
  // would have rejected. Both operations have to notice.
  let broken : @moonmoney.Rate = { scaled: 1L, scale: 100, }
  let mut inverted = false
  let _ = broken.inverse() catch {
    @moonmoney.MoneyError::Overflow(_) => {
      inverted = true
      exchange_rate("1")
    }
    _ => exchange_rate("1")
  }
  assert_eq(inverted, true)
  let mut converted = false
  let eur = @moonmoney.Currency::find("EUR").unwrap()
  let _ = amount(100L).convert(eur, broken) catch {
    @moonmoney.MoneyError::InvalidAmount(_, _) => {
      converted = true
      amount(0L)
    }
    _ => amount(0L)
  }
  assert_eq(converted, true)
}

///|
test "every rounding mode has a label" {
  assert_eq(@moonmoney.HalfUp.label(), "half-up")
  assert_eq(@moonmoney.HalfDown.label(), "half-down")
  assert_eq(@moonmoney.HalfEven.label(), "half-even")
  assert_eq(@moonmoney.Up.label(), "up")
  assert_eq(@moonmoney.Down.label(), "down")
  assert_eq(@moonmoney.Ceiling.label(), "ceiling")
  assert_eq(@moonmoney.Floor.label(), "floor")
}

///|
test "checked arithmetic reports overflow in both directions" {
  let mut up = false
  let _ = @moonmoney.add_checked(@moonmoney.max_amount(), 1L, "add") catch {
    @moonmoney.MoneyError::Overflow(_) => {
      up = true
      0L
    }
    _ => 0L
  }
  assert_eq(up, true)
  let mut down = false
  let _ = @moonmoney.add_checked(@moonmoney.min_amount(), -1L, "add") catch {
    @moonmoney.MoneyError::Overflow(_) => {
      down = true
      0L
    }
    _ => 0L
  }
  assert_eq(down, true)
  let mut sub_up = false
  let _ = @moonmoney.sub_checked(@moonmoney.min_amount(), 1L, "sub") catch {
    @moonmoney.MoneyError::Overflow(_) => {
      sub_up = true
      0L
    }
    _ => 0L
  }
  assert_eq(sub_up, true)
  let mut sub_down = false
  let _ = @moonmoney.sub_checked(@moonmoney.max_amount(), -1L, "sub") catch {
    @moonmoney.MoneyError::Overflow(_) => {
      sub_down = true
      0L
    }
    _ => 0L
  }
  assert_eq(sub_down, true)
}

///|
test "every error carries a message" {
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.DivisionByZero).length() > 0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.Overflow("add")).length() > 0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.CurrencyMismatch("USD", "JPY")).length() >
    0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.UnknownCurrency("ZZZ")).length() >
    0,
  )
  assert_true(
    @moonmoney.MoneyError::message(
      @moonmoney.AmbiguousCurrency("$", "USD, CAD"),
    ).length() >
    0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.InvalidAmount("x", "bad")).length() >
    0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.EmptyAllocation("a split")).length() >
    0,
  )
  assert_true(
    @moonmoney.MoneyError::message(@moonmoney.EmptyRatio).length() > 0,
  )
}

///|
test "a currency whose cash step is coarser than its minor unit" {
  // HUF: exponent 2, cash digits 0, cash step 5, so cash settles to 5.00.
  let huf = @moonmoney.Currency::find("HUF").unwrap()
  assert_eq(huf.cash_increment(), 500L)
  assert_eq(huf.has_cash_rounding(), true)
}

///|
test "allocation refuses the two impossible shapes" {
  let mut empty_weights = false
  let _ = amount(100L).allocate_ratios([]) catch {
    @moonmoney.MoneyError::EmptyAllocation(_) => {
      empty_weights = true
      []
    }
    _ => []
  }
  assert_eq(empty_weights, true)
  let mut too_small = false
  let smallest = @moonmoney.Money::of_minor(@moonmoney.min_amount(), usd())
  let _ = smallest.allocate(2) catch {
    @moonmoney.MoneyError::Overflow(_) => {
      too_small = true
      []
    }
    _ => []
  }
  assert_eq(too_small, true)
}
