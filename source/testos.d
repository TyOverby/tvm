import os;
import testmachine;
import machinecode;

import std.stdio;

/*
unittest {
  auto os = new OS(s => CodeUnit.init);

  CodeUnit cu = CodeUnit(
      "mylib",
      ["main": 0],
      (size_t[Reference]).init,
      [
        mixin(genOp("SET", "REGISTER + 1", "NEXT")),
        mixin(genData("1024")),
      ]);

  os.load(cu);
  os.step();

  assert(os.machine.registers[1].uinteger == 1024);
}
*/

unittest {
  auto units = [
    "twolib": CodeUnit(
        "twolib",
        ["extern": 0],
        (size_t[] [Reference]).init,
        [
          mixin(genOp("SET", "REGISTER", "NEXT")),
          mixin(genData("2048")),
          cast(Mem) Operation(OpType.RET)
        ]),
    "main": CodeUnit(
        "main",
        ["main": 0],
        [Reference("twolib", "extern"): [1]],
        [
          mixin(genOp("JUMP", "REGISTER", "NEXT")),
          mixin(genData("0"))
        ])
  ];

  auto os = new OS(s => units[s]);

  os.load("main");

  os.step();
  os.step();
  os.step();
  assert(os.machine.registers[0].uinteger == 2048);
}
