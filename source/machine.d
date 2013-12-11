module machine;

import std.stdio;

import machinecode;
import memory;

enum SystemCall: uint {
  PRINT,
  PRINT_STRING,
  HALT
}

/**
 * A class for a single machine.  This is the layer that emulates hardware.
 */
class Machine {
  Value[] registers;
  Memory  memory;

  Value programcounter = {uinteger: 0};
  Value stackpointer = {uinteger: 0};
  Value stackframe = {uinteger: 0};

  void delegate(SystemCall type) syscall;

  this() {
    registers = new Value[20];
    memory = new Memory;
  }

  /**
   * Gets the value out of an argument.
   */
  Value getValue(Argument arg) {
    switch (arg) {
      case Argument.REGISTER: .. case (Argument.REGISTER_DEREF - 1) :
        return registers[arg];
      case Argument.REGISTER_DEREF: .. case (Argument.REGISTER_DEREF_NEXT - 1) :
        return memory[registers[arg - Argument.REGISTER_DEREF].uinteger].value;
      case Argument.REGISTER_DEREF_NEXT: .. case (Argument.PUSH_POP - 1) :
        Value next = memory[programcounter.uinteger++].value;
        Value reg  = registers[arg - Argument.REGISTER_DEREF_NEXT];
        return memory[next.uinteger + reg.uinteger].value;
      case Argument.PUSH_POP:
        return memory[stackpointer.uinteger--].value;
      case Argument.PEEK:
        return memory[stackpointer.uinteger].value;
      case Argument.PICK:
        Value next = memory[programcounter.uinteger++].value;
        return memory[stackpointer.uinteger - next.uinteger].value;
      case Argument.STACK:
        return stackpointer;
      case Argument.PROGRAM:
        return programcounter;
      case Argument.NEXT:
        return memory[programcounter.uinteger++].value;
      case Argument.NEXT_DEREF:
        Value next = memory[programcounter.uinteger++].value;
        return memory[next.uinteger].value;
      default:
        Value v;
        v.uinteger = arg - Argument.LITERAL;
        return v;
    }
  }

  /**
   * Sets a value into an argument slot.
   * arg: The location to place the value.
   * val: The value to be stored.
   * op: The operation to performed on the values.
   */
  void setValue(Argument arg, Value val, Mem function(Value v1, Value v2) op) {
    switch (arg) {
      case Argument.REGISTER: .. case (Argument.REGISTER_DEREF - 1):
        registers[arg] = op(getValue(arg), val).value;
        return;
      case Argument.REGISTER_DEREF: .. case (Argument.REGISTER_DEREF_NEXT - 1):
        Value regi = registers[arg - Argument.REGISTER_DEREF];
        memory[regi.uinteger] = op(memory[regi.uinteger].value, val);
        return;
      case Argument.REGISTER_DEREF_NEXT: .. case (Argument.PUSH_POP - 1):
        Value next = memory[programcounter.uinteger++].value;
        Value regi = registers[arg - Argument.REGISTER_DEREF];
        memory[next.uinteger + regi.uinteger] =
          cast(Mem) op(memory[next.uinteger + regi.uinteger].value, val);
        return;
      case Argument.PUSH_POP:
        Value old = memory[stackpointer.uinteger].value;
        memory[++stackpointer.uinteger] = op(old, val);
        return;
      case Argument.PEEK:
        Value old = memory[stackpointer.uinteger].value;
        memory[stackpointer.uinteger] = op(old, val);
        return;
      case Argument.PICK:
        Value next = memory[programcounter.uinteger++].value;
        uint offset = stackpointer.uinteger + next.uinteger;
        memory[offset] = op(memory[offset].value, val);
        return;
      case Argument.STACK:
        stackpointer = cast(Value) op(stackpointer, val);
        return;
      case Argument.PROGRAM:
        programcounter = cast(Value) op(programcounter, val);
        return;
      case Argument.NEXT:
        throw new Exception("Assignment to NEXT");
      case Argument.NEXT_DEREF:
        Value next = memory[programcounter.uinteger++].value;
        Value value = memory[next.uinteger].value;
        memory[next.uinteger] = op(value, val);
        return;
      default:
        throw new Exception("Assignemnt to LITERAL");
    }
  }

  /**
   * A compile time function used for mixing in to the source.
   * ex: 
   * genop("+", "uinteger") => function(Value v1, Value v2) {
   *   Mem mem;
   *   mem.value.uinteger = (v1.uinteger + v2.uinteger);
   *   return mem;
   * }
   */
  static string genop(string operator, string type) {
    return "function(Value v1, Value v2) {" ~
      "Mem mem;" ~
      "mem.value." ~ type ~ "= (v1." ~
      type ~ " " ~ operator ~ " v2." ~ type ~ ");"~
      "return mem;}";
  }

  /**
   * Steps the machine by one operation.  
   * The logic in this function decodes the opcode.
   */
  void step() {
    Operation op = memory[programcounter.uinteger++].op;
    Value vb = getValue(op.b);
    Mem function (Value, Value) fn;
    if(op.opType < OpType.IFB) {
      switch(op.opType) {
        case OpType.UIADD:
          fn = mixin(genop("+", "uinteger"));
          break;
        case OpType.UISUB:
          fn = mixin(genop("-", "uinteger"));
          break;
        case OpType.UIMUL:
          fn = mixin(genop("*", "uinteger"));
          break;
        case OpType.UIDIV:
          fn = mixin(genop("/", "uinteger"));
          break;
        case OpType.UIMOD:
          fn = mixin(genop("%", "uinteger"));
          break;
        case OpType.SIMUL:
          fn = mixin(genop("*", "integer"));
          break;
        case OpType.SIDIV:
          fn = mixin(genop("/", "integer"));
          break;
        case OpType.FADD:
          fn = mixin(genop("+", "floating"));
          break;
        case OpType.FSUB:
          fn = mixin(genop("-", "floating"));
          break;
        case OpType.FMUL:
          fn = mixin(genop("*", "floating"));
          break;
        case OpType.FDIV:
          fn = mixin(genop("/", "floating"));
          break;

        case OpType.AND:
          fn = mixin(genop("&", "uinteger"));
          break;
        case OpType.OR:
          fn = mixin(genop("|", "uinteger"));
          break;
        case OpType.XOR:
          fn = mixin(genop("^", "uinteger"));
          break;

        case OpType.USHR:
          fn = mixin(genop(">>", "uinteger"));
          break;
        case OpType.USHL:
          fn = mixin(genop("<<", "uinteger"));
          break;
        case OpType.SSHR:
          fn = (v1, v2) {
            Mem mem;
            mem.value.integer = (v1.integer >> v2.uinteger);
            return mem;
          };
          break;
        default:
          throw new Exception("Not Reachable, 1");
      }
      setValue(op.a, vb, fn);

    } else if(op.opType < OpType.JUMP) {
      bool bop;
      Value va = getValue(op.a);

      switch(op.opType) {
        case OpType.IFB:
          bop = (va.uinteger & vb.uinteger) != 0;
          break;
        case OpType.IFC:
          bop = (va.uinteger & vb.uinteger) == 0;
          break;
        case OpType.IFE:
          bop = va.uinteger == vb.uinteger;
          break;
        case OpType.IFN:
          bop = va.uinteger != vb.uinteger;
          break;
        case OpType.UIIG:
          bop = va.uinteger > vb.uinteger;
          break;
        case OpType.UIIL:
          bop = va.uinteger < vb.uinteger;
          break;
        case OpType.SIIG:
          bop = va.integer > vb.integer;
          break;
        case OpType.SIIL:
          bop = va.integer < vb.integer;
          break;
        case OpType.FIG:
          bop = va.floating > vb.floating;
          break;
        case OpType.FIL:
          bop = va.floating < vb.floating;
          break;
        default:
          throw new Exception("Not Reachable 2");
      }

      if(!bop) {
        Operation throwaway = memory[programcounter.uinteger++].op;
        getValue(throwaway.b);
        getValue(throwaway.a);
      }
    } else {
      switch(op.opType) {
        case OpType.JUMP:
          Value ni = this.programcounter;
          Value sf = this.stackframe;

          this.programcounter = vb;

          this.memory[++stackpointer.uinteger] = cast(Mem) ni;
          this.memory[++stackpointer.uinteger] = cast(Mem) sf;
          this.stackframe = this.stackpointer;
          break;
        case OpType.RET:
          this.stackpointer = this.stackframe;
          this.stackframe = this.memory[stackpointer.uinteger--].value;
          this.programcounter = this.memory[stackpointer.uinteger--].value;
          break;
        case OpType.SET:
          setValue(op.a, vb, function(a,b){return cast(Mem)b;});
          break;
        case OpType.SYS:
          syscall(cast(SystemCall)vb.uinteger);
          break;
        default:
          throw new Exception("Not Reachable 3");

      }
    }
  }

  /**
   * Loads a program into memory.
   */
  void load(Mem[] program) {
    memory[0 .. program.length] = program;
  }
}
