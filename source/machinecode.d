module machinecode;

enum OpType: ubyte {
         // Math
         // Unsigned
  UIADD, // a = a + b Unsigned integer add
  UISUB, // a = a - b Unsigned integer subtraction
  UIMUL, // a = a * b Unsigned integer multiplication
  UIDIV, // a = a / b Unsigned integer division
  UIMOD, // a = a % b Unsigned integer modulo
         // Signed
  SIMUL, // a = a * b Signed integer multiplication
  SIDIV, // a = a / b Signed integer division
         // Floating
  FADD,  // a = a + b Floating addition
  FSUB,  // a = a - b Floating subtraction
  FMUL,  // a = a * b Floating multiplication
  FDIV,  // a = a / b Floating division

         // Logic
  AND,   // a = a & b
  OR,    // a = a | b
  XOR,   // a = a ^ b

         // Shifts
         // Unsigned
  USHR,   // a = a >>> b Unsigned right shift
  USHL,   // a = a << b  Unsigned left shift
         // Signed
  SSHR,   // a = a >> b  Signed right shift. propagates negative

         // Conditionals
  IFB,   // if (a & b != 0)
  IFC,   // if (a & b == 0)
  IFE,   // if (a == b)
  IFN,   // if (a != b)

         // Unsigned
  UIIG,  // if (a > b)
  UIIL,  // if (a < b)
         // Signed
  SIIG,  // if (a > b)
  SIIL,  // if (a < b)
         // Floating
  FIG,   // if (a > b)
  FIL,   // if (a < b)

  JUMP,
  RET,
  SET,

  SYS,
}

enum Argument: ubyte {
  REGISTER = 0,             // a  | registers are 0 - 19 (inclusive)
  REGISTER_DEREF = 20,      // [a] | regester dereference are 20 - 39 (inclusive)
  REGISTER_DEREF_NEXT = 40, // [a + next] | register
  PUSH_POP = 60,            // changes depending on if used in a get or a set
  PEEK,                     // [sp]
  PICK,                     // [sp + next]
  STACK,                    // sp
  PROGRAM,                  // pc
  NEXT,                     // next
  NEXT_DEREF,               // [next]
  LITERAL,                  // num | all values from LITERAL on can be used as literals
}

struct Operation {
  OpType opType;
  Argument a;
  Argument b;
  ubyte filler = 0;
}
unittest {
  assert(Operation.sizeof == uint.sizeof);
}

union Value {
  uint uinteger;
  int integer;
  float floating;
}
unittest {
  assert(Value.sizeof == uint.sizeof);
}

union Mem {
  Operation op;
  Value value;
}
unittest {
  assert(Mem.sizeof == uint.sizeof);
}
