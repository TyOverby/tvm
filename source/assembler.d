module assembler;

import os;
import machinecode;

import std.string;
import std.uni;
import std.algorithm: map, filter, all;
import std.array;
import std.stdio;
import std.conv;

/*
  _  _ ___ ___ ___     ___ ___     ___  ___    _   ___  ___  _  _ ___ 
 | || | __| _ \ __|   | _ ) __|   |   \| _ \  /_\ / __|/ _ \| \| / __|
 | __ | _||   / _|    | _ \ _|    | |) |   / / _ \ (_ | (_) | .` \__ \
 |_||_|___|_|_\___|   |___/___|   |___/|_|_\/_/ \_\___|\___/|_|\_|___/

*/                                                                      

string trim(string s) {
  return s.chomp(" ").chompPrefix(" ");
}

string clearComments(string s) {
  auto first = s.indexOf("#");
  if(first == -1) {
    return s.trim.toLower;
  } else {
    return s[0 .. first].trim.toLower;
  }
}

CodeUnit parseEntire(string file) {
  string[] lines = file.splitLines()
    .map!(s => clearComments(s))
    .filter!("a.length > 1").array;


  assert(lines.length > 1);
  assert(lines[0].startsWith("library"));
  auto index = lines[0].indexOf("library");

  string libname = clearComments(lines[0][index  + "library".length .. $]);
  lines = lines[1 .. $];

  string[] exports;
  size_t[string] labels;
  size_t[] [Reference] imports;

  lines = parseExports(lines, exports);
  Mem[] code = parseOps(lines, labels, imports);

  return CodeUnit(libname, labels, imports, code);
}

string[] parseExports(string[] lines, out string[] exports) {
  uint lastIndex = 0;
  foreach(uint index, string line; lines) {
    if(!line.startsWith("export")) {
      lastIndex = index;
      break;
    } else {
      auto split = line.split(" ");
      assert(split.length == 2);
      exports ~= split[1];
    }
  }

  return lines[lastIndex..$];
}

unittest {
  auto strs = [
    "export bazzz",
    "export fuz",
    "more shit"
    ];

  string[] exports;
  string[] rest = parseExports(strs, exports);
  assert(rest == ["more shit"]);
  assert(exports == ["bazzz", "fuz"]);
}

Mem[] parseOps(string[] lines, ref size_t[string] labels, ref size_t[] [Reference] imports) {
  size_t offset = 0;
  Mem[] mem;
  foreach(line; lines) {
    line = line.trim;
    if(line.startsWith(":")) {
      // lable definition, data element
      // TODO: finish
      string rest = line[1 .. $];
      labels[rest] = offset;
    } else {
      mem ~= parseOp(line, offset, imports);
      offset = mem.length;
    }
  }

  return mem;
}

unittest {
  Mem[] mem;

  size_t[string] labels;
  size_t[] [Reference] imports;

  mem = parseOps([":foo", "set r1 bar.foo",":gug", "set r2 bar.baz"], labels, imports);
  assert(mem.length == 4);
  assert(mem[0].op == Operation(OpType.SET, Argument.REGISTER, Argument.NEXT));
  assert(mem[1].value.uinteger == 0);

  assert(mem[2].op == Operation(OpType.SET, cast(Argument)(Argument.REGISTER + 1), Argument.NEXT));
  assert(mem[3].value.uinteger == 0);

  assert(labels["foo"] == 0);
  assert(imports[Reference("bar", "foo")] == [1]);
  assert(labels["gug"] == 2);
  assert(imports[Reference("bar", "baz")] == [3]);
}

Mem[] parseOp(string line, ref size_t offset, ref size_t[] [Reference] imports) {
  string[] sections = line.trim.split(" ").map!trim.filter!("a.length > 0").array;

  size_t[] [Reference] myImports;

  Mem[] mem;
  OpType optype = parseOperator(sections[0]);

  Mem op;

  if (optype == OpType.JUMP || optype == OpType.SYS) {
    assert(sections.length == 2, "expected 2 sections, got: " ~ line);

    Argument argb = parseArgument(sections[1], mem, myImports);
    op = cast(Mem) Operation(optype, Argument.REGISTER, argb);
  } else if (optype == OpType.RET) {
    assert(sections.length == 1, "expected 1 section, got: " ~ line);

    op = cast(Mem) Operation(optype, Argument.REGISTER, Argument.REGISTER);
  } else {
    assert(sections.length == 3, "expected 3 sections, got: " ~ to!string(sections.length) ~ " from \""  ~ line ~ "\"");

    Argument argb = parseArgument(sections[2], mem, myImports);
    Argument arga = parseArgument(sections[1], mem, myImports);
    op = cast(Mem) Operation(optype, arga, argb);
  }

  foreach (Reference r, size_t[] arr; myImports) {
    if (r !in imports) {
      imports[r] = [];
    }

    foreach (i; arr) {
      imports[r] ~= i + offset + 1;
    }
  }

  return [op] ~ mem;
}
unittest {
  Mem[] mem;
  size_t offset;
  size_t[] [Reference] imports;

  mem = parseOp("set r1 5", offset, imports);
  assert(mem.length == 1);
  assert(mem[0].op == Operation(OpType.SET, Argument.REGISTER, cast(Argument)(Argument.LITERAL + 5)));

  mem = parseOp("set [10] [500]", offset, imports);
  assert(mem.length == 3);
  assert(mem[0].op == Operation(OpType.SET, Argument.NEXT_DEREF, Argument.NEXT_DEREF));
  assert(mem[1].value.uinteger == 500);
  assert(mem[2].value.uinteger == 10);

  mem = parseOp("set push r19", offset, imports);
  assert(mem.length == 1);
  assert(mem[0].op == Operation(OpType.SET, Argument.PUSH_POP, cast(Argument)(Argument.REGISTER + 18)));

  offset = 75;
  mem = parseOp("set push foo.bar", offset, imports);
  assert(mem.length == 2);
  assert(mem[0].op == Operation(OpType.SET, Argument.PUSH_POP, Argument.NEXT));
  assert(mem[1].value.uinteger == 0);
  assert(imports[Reference("foo", "bar")] == [76]);

  mem = parseOp("jump 5", offset, imports);
  assert(mem.length == 1);
  assert(mem[0].op.opType == OpType.JUMP);
  assert(mem[0].op.b == cast(Argument)(Argument.LITERAL + 5));

  mem = parseOp("set   r2 otherlib.x", offset, imports);
  assert(mem.length == 2);
  assert(imports[Reference("otherlib", "x")] == [76]);
}

OpType parseOperator(string op)  {
  return to!OpType(op.toUpper);
}

Argument parseArgument(string arg, ref Mem[] mem, ref size_t[] [Reference] imports) {
  // derefs
  if (arg.indexOf('[') != -1) {
    // an addition, either [sp + next] or [r + next]
    if (arg.indexOf('+') != -1) {
      long pindex = arg.indexOf('+');
      if(arg.indexOf("sp") != -1) {
        string rest = arg[pindex + 1 .. $ - 1];
        if(rest.isNumeric) {
          bool isShort;
          mem ~= cast(Mem)(parseNumber(rest, isShort));
        } else {
          parseReference(rest, mem, imports);
        }

        return cast(Argument)(Argument.PICK);

      } else {
        // register extraction
        string reg = arg[2 .. pindex];
        uint number = to!uint(reg);
        assert(number <= 20);
        assert(number >= 1);

        // number extraction
        string num = arg[pindex + 1 .. $-1];
        if(num.isNumeric || num.startsWith("0x")) {
          bool isShort;
          mem ~= cast(Mem)(parseNumber(num, isShort));
        } else {
          parseReference(num, mem, imports);
        }

        return cast(Argument)(Argument.REGISTER_DEREF_NEXT + number - 1);
      }
    } else if (arg == "[sp]" || arg == "peek") {
      return Argument.PEEK;
    } else if ((arg.length == 4 || arg.length == 5) && !arg[1 .. $ - 1].isNumeric) {
      // deref register
      string num = arg[2 .. $ - 1];
      return cast(Argument)(Argument.REGISTER_DEREF + to!uint(num) - 1);
    } else {
      string inner = arg[1 .. $ - 1];
      if (inner.isNumeric) {
        bool isShort;
        mem ~= cast(Mem)(parseNumber(inner, isShort));
      } else {
        parseReference(inner, mem, imports);
      }
      return Argument.NEXT_DEREF;
    }
  } else {
    if (arg == "push" || arg == "pop") {
      return Argument.PUSH_POP;
    } else if (arg == "peek") {
      return Argument.PEEK;
    } else if (arg == "sp" || arg == "stack") {
      return Argument.STACK;
    } else if (arg == "pc" || arg == "program") {
      return Argument.PROGRAM;
    } else if ((arg.length == 2 || arg.length == 3) && arg[0] == 'r' && arg[1 .. $].isNumeric) {
      // registers
      string num = arg[1 .. $];
      uint number = to!uint(num);
      assert(number <= 20);
      assert(number >= 1);
      return cast(Argument)(Argument.REGISTER + number - 1);
    } else if (arg.isNumeric || arg.startsWith("0x")) {
      // number literals
      bool lowEnough = false;
      Mem extra = cast(Mem)(parseNumber(arg, lowEnough));

      if(lowEnough) {
        return cast(Argument)(extra.value.uinteger + Argument.LITERAL);
      }

      mem ~= extra;
      return Argument.NEXT;
    } else {
      // it's probably a reference to a library location
      parseReference(arg, mem, imports);
      return Argument.NEXT;
    }
  }
}

unittest {
  Mem[] mem;
  size_t[] [Reference] imports;

  auto arg = parseArgument("r1", mem, imports);
  assert(arg == Argument.REGISTER);
  assert(mem.length == 0);

  arg = parseArgument("[r1]", mem, imports);
  assert(arg == Argument.REGISTER_DEREF);
  assert(mem.length == 0);

  arg = parseArgument("[r2]", mem, imports);
  assert(arg == Argument.REGISTER_DEREF + 1);
  assert(mem.length == 0);

  arg = parseArgument("[r1+5]", mem, imports);
  assert(arg == Argument.REGISTER_DEREF_NEXT);
  assert(mem.length == 1);
  assert(mem[0].value.uinteger == 5);

  arg = parseArgument("[r2+test.foo]", mem, imports);
  assert(arg == Argument.REGISTER_DEREF_NEXT + 1);
  assert(mem.length == 2);
  assert(mem[1].value.uinteger == 0);
  assert(imports[Reference("test", "foo")] == [1]);

  arg = parseArgument("push", mem, imports);
  assert(arg == Argument.PUSH_POP);
  arg = parseArgument("pop", mem, imports);
  assert(arg == Argument.PUSH_POP);

  arg = parseArgument("peek", mem, imports);
  assert(arg == Argument.PEEK);
  arg = parseArgument("[sp]", mem, imports);
  assert(arg == Argument.PEEK);

  arg = parseArgument("[sp+50]", mem, imports);
  assert(arg == Argument.PICK);
  assert(mem.length == 3);
  assert(mem[2].value.uinteger == 50);

  arg = parseArgument("sp", mem, imports);
  assert(arg == Argument.STACK);
  assert(mem.length == 3);

  arg = parseArgument("pc", mem, imports);
  assert(arg == Argument.PROGRAM);
  assert(mem.length == 3);

  arg = parseArgument("0x10c", mem, imports);
  assert(arg == Argument.NEXT);
  assert(mem.length == 4);
  assert(mem[3].value.uinteger == 0x10c);

  arg = parseArgument("-30", mem, imports);
  assert(arg == Argument.NEXT);
  assert(mem.length == 5);
  assert(mem[4].value.integer == -30);

  arg = parseArgument("4.56", mem, imports);
  assert(arg == Argument.NEXT);
  assert(mem.length == 6);
  assert(mem[5].value.floating == 4.56f);

  arg = parseArgument("[50]", mem, imports);
  assert(arg == Argument.NEXT_DEREF);
  assert(mem.length == 7);
  assert(mem[6].value.uinteger == 50);

  arg = parseArgument("[foo.bar]", mem, imports);
  assert(arg == Argument.NEXT_DEREF);
  assert(mem.length == 8);
  assert(mem[7].value.uinteger == 0);
  assert(imports[Reference("foo", "bar")] == [7]);

  arg = parseArgument("[foo.bar]", mem, imports);
  assert(arg == Argument.NEXT_DEREF);
  assert(mem.length == 9);
  assert(mem[8].value.uinteger == 0);
  assert(imports[Reference("foo", "bar")] == [7,8]);

  arg = parseArgument("5", mem, imports);
  assert(arg == cast(Argument)(Argument.LITERAL + 5));
  assert(mem.length == 9);
}

void parseReference(string s, ref Mem[] mem,  ref size_t[] [Reference] imports)  {
  auto num = s;
  long period = num.indexOf('.');
  assert(period != -1);

  string before = num[0 .. period];
  string after =  num[period + 1 .. $];
  Reference r = reference(before, after);

  if (r in imports) {
    imports[r] ~= mem.length;
  } else {
    imports[r] = [mem.length];
  }

  mem ~= cast(Mem)(cast(Value)(0));
}

unittest {
  string refer = "mylib.foo";
  Reference actual = Reference("mylib", "foo");

  Mem[] mem;
  size_t[] [Reference] imports;

  parseReference(refer, mem, imports);

  assert(mem.length == 1);
  assert(imports[actual].length == 1);
  assert(imports[actual] == [0]);

  parseReference(refer, mem, imports);
  assert(mem.length == 2);
  assert(imports[actual].length == 2);
  assert(imports[actual] == [0, 1]);
}


Value parseNumber(string arg, out bool isShort) {
  string s1 = arg.dup;
  char[] s = cast(char[])(s1);

  Value value;

  // hex
  if (arg.startsWith("0x")) {
    s = s[2 .. $];
    uint val = parse!uint(s, 16);
    value = (cast(Value)(val));
    if (val < ubyte.max - Argument.LITERAL) {
      isShort = true;
    }
  } else
  // floating
  if (arg.indexOf(".") != -1) {
    float val = parse!float(s);
    value.floating = val;
  } else
  // negative int
  if (arg.startsWith("-")) {
    int val = parse!int(s);
    value = cast(Value)(val);
  } else
  // positive int
  {
    uint val = parse!uint(s);
    value = cast(Value)(val);

    if (val < (ubyte.max - Argument.LITERAL)) {
      isShort = true;
    }
  }

  return value;
}

Value parseNumber(string arg) {
  bool isShort;
  return parseNumber(arg, isShort);
}

unittest {
  assert(parseNumber("1.54").floating == 1.54f);
  assert(parseNumber("1234").uinteger == 1234, "1234");
  assert(parseNumber("-54").integer == -54, "-54");
  assert(parseNumber("0x10c").uinteger == 0x10c, "0x10c");
}

