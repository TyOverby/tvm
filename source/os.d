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

/**
 * Returns the package name from a string reference.
 */
string pack(Reference r) {
  auto idx = r.indexOf('.');
  return r[0 .. idx];
}

/**
 * Returns the label name from a reference.
 */
string name(Reference r) {
  auto idx = r.indexOf('.');
  return r[idx + 1 .. $];
}

unittest {
  assert(refPack("foo.bar") == "foo");
  assert(refName("foo.bar") == "bar");
}

/**
 * The structure of the object file.
 */
struct CodeUnit {
  string packageName;

  // A map from the name of an export to the offset in code.
  size_t[string] exports;
  // A map from the name of a reference to the list of offsets in the code.
  size_t[] [Reference] imports;

  // The actual code.
  Mem[] code;
}



struct Info {
  // The offset into main memory that a library lives.
  size_t offset;
  // The length of the library.
  size_t length;
}

class OS {
  Machine machine;

  CodeUnit[string] packages;
  Info[string] info;

  // A pointer into memory where you start laying libraries down into memory.
  size_t code_pointer = 256 * 128;

  // The location of main
  uint main = 0;

  // A function pointer that is set by the loader to fetch a library.
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
    // If we've already loaded it, there's nothing to do.
    if(unit.packageName in packages) {
      return;
    }

    // Throw the unit into our map.
    packages[unit.packageName] = unit;

    // Decrement the code pointer by the length of this unit of code.
    code_pointer -= unit.code.length;
    // Store a reference to the code_pointer that won't be changed by subsequent calls to load
    auto cp = code_pointer;
    // Copy the code from the codeuint into the machine starting at code_pointer
    machine.memory[code_pointer .. code_pointer + unit.code.length] = unit.code;

    debugLine("placing: ", unit.packageName, " at ", code_pointer);

    // Store our information about the code unit in our class-local map.
    info[unit.packageName] = Info(code_pointer, unit.code.length);

    // The first library to define "main" as a label is the one that we start at.
    if("main" in unit.exports) {
      if(machine.programcounter.uinteger == 0){
        main = cast(uint)(code_pointer + unit.exports["main"]);
        machine.programcounter.uinteger = main;
      }
    }
    
    // For each import
    foreach(reference, offsets; unit.imports) {
      // For each offset from that particular import
      foreach(offset; offsets) {
        // Compute the offset into main memory 
        auto actualOffset = cp + offset;
        load(reference.pack);

        auto loadedPackage = packages[reference.pack];

        // Lookup where that reference was loaded into
        size_t loadedAddr = loadedPackage.exports[reference.name] +
          info[reference.pack].offset;
        Value v;
        v.uinteger = cast(uint) loadedAddr;

        debugLine("overwritten with ", v.uinteger);

        auto x = machine.memory[actualOffset];
        // Overwrite memory
        machine.memory[actualOffset] = cast(Mem) v;

        debugLine("offset: ", offset, ", cp: ", cp);

        debugLine("overwritten, was: ",x.value.uinteger);
        auto y = machine.memory[actualOffset-1];
        debugLine("overwritten, was: ",y.op);
      }
    }
  }

  void load(string pack) {
    // Delegate to the functionpointer fetch
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
      debugLine("With: ", op.opType, "(", op.a, ", ", op.b, ")");
    }

    try {
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
