module vm;

import os;
import comp;

import std.getopt;

enum LogLevel: ubyte {
  NONE,
  LOW,
  HIGH
}

version(VM) {
void main(string[] args) {
  LogLevel ll = LogLevel.NONE;
  string lib = "";

  getopt(args,
      "loglevel", &ll,
      "lib|l", &lib);

  assert(lib.length > 0, "you must pass a file into the vm");

  try {
    OS os = new OS(lib => fetch(lib), ll);
    os.load(fetch(lib));
    os.run();
  } catch (Exception e) {
    if(ll >= LogLevel.LOW) {
      throw e;
    }
  }
}
}
