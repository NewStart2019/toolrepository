class PrecisionCalculator {
  constructor(initialValue = 0) {
    this.value = new Decimal(initialValue);
  }

  add(value) {
    this.value = this.value.plus(new Decimal(value));
    return this;
  }

  subtract(value) {
    this.value = this.value.minus(new Decimal(value));
    return this;
  }

  multiply(value) {
    this.value = this.value.times(new Decimal(value));
    return this;
  }

  divide(value) {
    if (value === 0) throw new Error('Division by zero is not allowed');
    this.value = this.value.dividedBy(new Decimal(value));
    return this;
  }

  toFixed(digits) {
    return parseFloat(this.value.toFixed(digits));
  }

  valueOf() {
    return this.value.toNumber();
  }
}