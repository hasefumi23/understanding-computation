# frozen_string_literal: true

class Number < Struct.new(:value)
  def to_ruby
    "-> e { #{value.inspect} }"
  end

  def evaluate(environment)
    self
  end

  def reducible?
    false
  end

  def to_s
    value.to_s
  end

  def inspect
    "<<#{self}>>"
  end
end

class Add < Struct.new(:left, :right)
  def evaluate(environment)
    Number.new(left.evaluate(environment).value + right.evaluate(environment).value)
  end

  def reducible?
    true
  end

  def reduce(environment)
    if left.reducible?
      Add.new(left.reduce(environment), right)
    elsif right.reducible?
      Add.new(left, right.reduce(environment))
    else
      Number.new(left.value + right.value)
    end
  end

  def to_s
    "#{left} + #{right}"
  end

  def inspect
    "<<#{self}>>"
  end
end

class Multiply < Struct.new(:left, :right)
  def evaluate(environment)
    Number.new(left.evaluate(environment).value * right.evaluate(environment).value)
  end

  def reducible?
    true
  end

  def reduce(environment)
    if left.reducible?
      Multiply.new(left.reduce(environment), right)
    elsif right.reducible?
      Multiply.new(left, right.reduce(environment))
    else
      Number.new(left.value * right.value)
    end
  end

  def to_s
    "#{left} * #{right}"
  end

  def inspect
    "<<#{self}>>"
  end
end

class Boolean < Struct.new(:value)
  def to_ruby
    "-> e { #{value.inspect} }"
  end

  def evaluate(environment)
    self
  end

  def reducible?
    false
  end

  def to_s
    value.to_s
  end

  def inspect
    "<<#{self}>>"
  end
end

class LessThan < Struct.new(:left, :right)
  def evaluate(environment)
    Boolean.new(left.evaluate(environment).value < right.evaluate(environment).value)
  end

  def reducible?
    true
  end

  def to_s
    "#{left} < #{right}"
  end

  def inspect
    "<<#{self}>>"
  end

  def reduce(environment)
    if left.reducible?
      LessThan.new(left.reduce(environment), right)
    elsif right.reducible?
      LessThan.new(left, right.reduce(environment))
    else
      Boolean.new(left.value < right.value)
    end
  end
end

class Variable < Struct.new(:name)
  def evaluate(environment)
    environment[name]
  end

  def to_s
    name.to_s
  end

  def inspect
    "<<#{self}>>"
  end

  def reducible?
    true
  end

  def reduce(environment)
    environment[name]
  end
end

class DoNothing
  def evaluate(environment)
    environment
  end

  def to_s
    'do-nothing'
  end

  def inspect
    "<<#{self}>>"
  end

  def ==(other_statement)
    other_statement.instance_of?(DoNothing)
  end

  def reducible?
    false
  end
end

class Assign < Struct.new(:name, :expression)
  def evaluate(environment)
    environment.merge(name => expression.evaluate(environment))
  end

  def to_s
    "#{name} = #{expression}"
  end

  def inspect
    "<<#{self}>>"
  end

  def reducible?
    true
  end

  def reduce(environment)
    if expression.reducible?
      [Assign.new(name, expression.reduce(environment)), environment]
    else
      [DoNothing.new, environment.merge(name => expression)]
    end
  end
end

class If < Struct.new(:condition, :consequence, :alternative)
  def evaluate(environment)
    case condition.evaluate(environment)
    when Boolean.new(true)
      consequence.evaluate(environment)
    when Boolean.new(false)
      alternative.evaluate(environment)
    end
  end

  def to_s
    "if (#{condition}) { #{consequence} ) else { #{alternative} }"
  end

  def inspect
    "<<#{self}>>"
  end

  def reducible?
    true
  end

  def reduce(environment)
    if condition.reducible?
      [If.new(condition.reduce(environment), consequence, alternative), environment]
    else
      case condition
      when Boolean.new(true)
        [consequence, environment]
      when Boolean.new(false)
        [alternative, environment]
      end
    end
  end
end

class Machine < Struct.new(:statement, :environment)
  def step
    self.statement, self.environment = statement.reduce(environment)
  end

  def run
    while statement.reducible?
      puts "#{statement}, #{environment}"
      step
    end

    puts "#{statement}, #{environment}"
  end
end

class Sequence < Struct.new(:first, :second)
  def evaluate(environment)
    second.evaluate(first.evaluate(environment))
  end

  def to_s
    "#{first}; #{second}"
  end

  def inspect
    "<<#{self}>>"
  end

  def reducible?
    true
  end

  def reduce(environment)
    case first
    when DoNothing.new
      [second, environment]
    else
      reduced_first, reduced_environment = first.reduce(environment)
      [Sequence.new(reduced_first, second), reduced_environment]
    end
  end
end

class While < Struct.new(:condition, :body)
  def evaluate(environment)
    case condition.evaluate(environment)
    when Boolean.new(true)
      evaluate(body.evaluate(environment))
    when Boolean.new(false)
      environment
    end
  end

  def to_s
    "While (#{condition}) { #{body} }"
  end

  def inspect
    "<<#{self}>>"
  end

  def reducible?
    true
  end

  def reduce(environment)
    [If.new(condition, Sequence.new(body, self), DoNothing.new), environment]
  end
end

# === INFO: Executeable ===

statement = While.new(
  LessThan.new(Variable.new(:x), Number.new(5)),
  Assign.new(:x, Multiply.new(Variable.new(:x), Number.new(3)))
)

statement = Sequence.new(
  Assign.new(:x, Add.new(Number.new(1), Number.new(1))),
  Assign.new(:y, Add.new(Variable.new(:x), Number.new(3)))
)

Number.new(23).evaluate({})
Variable.new(:x).evaluate(x: Number.new(23))
LessThan.new(
  Add.new(Variable.new(:x), Number.new(2)),
  Variable.new(:y)
).evaluate(x: Number.new(2), y: Number.new(5))

# 評価に失敗する例
Machine.new(
  Sequence.new(
    Assign.new(:x, Boolean.new(true)),
    Assign.new(:x, Add.new(Variable.new(:x), Number.new(1)))
  ),
  {}
)

Machine.new(
  While.new(
    LessThan.new(Variable.new(:x), Number.new(5)),
    Assign.new(:x, Multiply.new(Variable.new(:x), Number.new(3)))
  ),
  x: Number.new(1)
)

Machine.new(
  Sequence.new(
    Assign.new(:x, Add.new(Number.new(1), Number.new(1))),
    Assign.new(:y, Add.new(Variable.new(:x), Number.new(3)))
  ),
  {}
)

Machine.new(
  If.new(
    Variable.new(:x),
    Assign.new(:y, Number.new(1)),
    Assign.new(:y, Number.new(2))
  ),
  x: Boolean.new(true)
)

Machine.new(
  If.new(
    Variable.new(:x),
    Assign.new(:y, Number.new(1)), DoNothing.new
  ),
  x: Boolean.new(false)
)

Machine.new(
  Assign.new(:x, Add.new(Variable.new(:x), Number.new(1))),
  x: Number.new(2)
)

expression = Add.new(
  Multiply.new(Number.new(1), Number.new(2)),
  Multiply.new(Number.new(3), Number.new(4))
)

Machine.new(
  expression = Add.new(
    Multiply.new(Number.new(1), Number.new(2)),
    Multiply.new(Number.new(3), Number.new(4))
  )
)

Machine.new(
  LessThan.new(Number.new(5), Add.new(Number.new(2), Number.new(2)))
)

Machine.new(
  Add.new(Variable.new(:x), Variable.new(:y)),
  x: Number.new(3), y: Number.new(4)
)
