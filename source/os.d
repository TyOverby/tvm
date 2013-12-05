module os;

import std.file: readText;
import std.stdio;
import std.conv;
import std.string;

import cerealed;

import machine;
import machinecode;
import comp;
import vm;

alias string Reference;

Reference reference(string pack, string name) {
  return pack ~ "." ~ name;
}

string pack(Reference r) {
  auto idx = r.indexOf('.');
  return r[0 .. idx];
}

string name(Reference r) {
  auto idx = r.indexOf('.');
  return r[idx + 1 .. $];
}

unittest {
  assert(refPack("foo.bar") == "foo");
  assert(refName("foo.bar") == "bar");
}


struct CodeUnit {
  string packageName;

  // A map from the name of an export to the offset in code.
  size_t[string] exports;

  size_t[] [Reference] imports;

  Mem[] code;
}


struct Info {
  size_t offset;
  size_t length;
}

class OS {
  Machine machine;

  CodeUnit[string] packages;
  Info[string] info;

  size_t code_pointer = 256 * 128;

  uint main = 0;

  CodeUnit delegate(string pack) fetch;
  LogLevel ll;

  this(CodeUnit delegate(string pack) fetch, LogLevel ll) {
    machine = new Machine;
    machine.syscall = &handleSysCall;
    this.fetch = fetch;
    this.ll = ll;
  }

  void debugLine(Args...)(Args args) {
    if (ll == LogLevel.HIGH) {
      writeln(args);
    }
  }

  void load(CodeUnit unit) {
    if(unit.packageName in packages) {
      return;
    }

    packages[unit.packageName] = unit;

    code_pointer -= unit.code.length;
    auto cp = code_pointer;
    machine.memory[code_pointer .. code_pointer + unit.code.length] = unit.code;

    debugLine("placing: ", unit.packageName, " at ", code_pointer);

    info[unit.packageName] = Info(code_pointer, unit.code.length);

    if("main" in unit.exports) {
      if(machine.programcounter.uinteger == 0){
        main = cast(uint)(code_pointer + unit.exports["main"]);
        machine.programcounter.uinteger = main;
      }
    }

    foreach(reference, offsets; unit.imports) {
      foreach(offset; offsets) {
        auto actualOffset = cp + offset;
        load(reference.pack);

        auto loadedPackage = packages[reference.pack];

        size_t loadedAddr = loadedPackage.exports[reference.name] +
          info[reference.pack].offset;
        Value v;
        v.uinteger = cast(uint) loadedAddr;

        debugLine("overwritten with ", v.uinteger);

        auto x = machine.memory[actualOffset];
        machine.memory[actualOffset] = cast(Mem) v;

        debugLine("offset: ", offset, ", cp: ", cp);

        debugLine("overwritten, was: ",x.value.uinteger);
        auto y = machine.memory[actualOffset-1];
        debugLine("overwritten, was: ",y.op);
      }
    }
  }

  void load(string pack) {
    CodeUnit unit = fetch(pack);
    load(unit);
  }


  void step() {
    if(main == 0) {
      throw new Exception("no main found!");
    }

    Value pc = machine.programcounter;

    void print() {
      Operation op = machine.memory[pc.uinteger].op;
      //debugLine("Crashed at: " ~ to!string(pc.uinteger));
      debugLine("With: ", op.opType, "(", op.a, ", ", op.b, ")");
    }

    try {
      //debugLine("currently facing");
      //print();
      machine.step();
    } catch (Exception e) {
      debugLine("Crashed at: " ~ to!string(pc.uinteger));
      print();

      throw e;
    }
  }

  bool running = false;

  void run() {
    running = true;
    while(running) {
      step();
      if(machine.programcounter.uinteger >= machine.memory.max) {
        running = false;
      }
    }
  }

  void handleSysCall(SystemCall type) {
    final switch (type) {
      case SystemCall.PRINT:
        Value v = machine.registers[0];
        writeln(v.uinteger);
        break;
      case SystemCall.PRINT_STRING:
        writeln("not implemented");
        break;
      case SystemCall.HALT:
        running = false;
        debugLine("system halted");
        break;
    }
  }
}
