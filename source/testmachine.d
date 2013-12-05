import machine;
import machinecode;
import os;

static string genOp(string optype, string argA, string argB) {
  return "cast(Mem) Operation(" ~
    "OpType." ~ optype ~ ", " ~
    "cast(Argument) (Argument." ~ argA ~ "), " ~
    "cast(Argument) (Argument." ~ argB ~ "))";
}

static string genData(string value) {
  return "cast(Mem) Value(" ~ value ~ ")";
}

// Set a register
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "REGISTER", "LITERAL + 1"))
  ];
  m.load(program);
  m.step();

  assert(m.registers[0].uinteger == 1);
}

// Set a register to a large number
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "REGISTER + 1", "NEXT")),
    mixin(genData("1024"))
  ];
  m.load(program);
  m.step();
  assert(m.registers[1].uinteger == 1024);
}

// Set a value in memory to a large number
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "NEXT_DEREF", "NEXT")),
    mixin(genData("1024")),
    mixin(genData("50"))
  ];

  m.load(program);
  m.step();

  assert(m.memory[50].value.uinteger == 1024);
}

// Several values in registers
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "REGISTER", "LITERAL + 2")),
    mixin(genOp("SET", "REGISTER", "LITERAL + 3"))

  ];

  m.load(program);
  m.step();
  assert(m.registers[0].uinteger == 2);
  m.step();
  assert(m.registers[0].uinteger == 3);
}

// Several values in memory
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "NEXT_DEREF", "LITERAL + 2")),
    mixin(genData("45")),
    mixin(genOp("SET", "NEXT_DEREF", "LITERAL + 3")),
    mixin(genData("35")),

  ];

  m.load(program);
  m.step();
  assert(m.memory[45].value.uinteger == 2);
  m.step();
  assert(m.memory[35].value.uinteger == 3);
}

// Test the stack
unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("SET", "PUSH_POP", "LITERAL + 5")),
    mixin(genOp("SET", "REGISTER", "PUSH_POP"))
  ];
  m.load(program);
  m.stackpointer.uinteger = cast(uint) program.length;

  m.step();
  assert(m.stackpointer.uinteger == program.length + 1);
  assert(m.memory[m.stackpointer.uinteger].value.uinteger == 5);

  m.step();
  assert(m.stackpointer.uinteger == program.length);
  assert(m.registers[0].uinteger == 5);

}

unittest {
  auto m = new Machine();
  Mem[] program = [
    mixin(genOp("UIADD", "REGISTER", "LITERAL + 1")),
    mixin(genOp("SET", "PROGRAM", "LITERAL"))
  ];
  m.load(program);

  for(uint i=0; i < 10; i++) {
    assert(m.registers[0].uinteger == i);
    m.step();
    m.step();
  }
}
