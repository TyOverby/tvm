module comp;

import assembler;
import cerealed;
import os;

import std.file;
import std.getopt;
import std.stdio: writeln;
import std.string;

void compile(string libname) {
  string file = readText(libname ~ ".asm");
  CodeUnit cu = parseEntire(file);
  writeln(cu.imports);

  auto cerealiser = new Cerealiser();
  cerealiser ~= cu;

  write(libname ~ ".o", cerealiser.bytes);
}

CodeUnit reinstate(string libname) {
  void[] contents = read(libname ~ ".o");

  auto decerealiser = new Decerealiser(cast(byte[])contents);

  CodeUnit cu = decerealiser.value!CodeUnit;
  return cu;
}

CodeUnit fetch(string libname) {
  if (exists(libname ~ ".o")) {
    return reinstate(libname);
  } else {
    if (exists(libname ~ ".asm")) {
      compile(libname);
      return reinstate(libname);
    } else {
      throw new Exception("Library not found: \"" ~ libname ~ "\"");
    }
  }
}

string withoutExt(string fn) {
  auto idx = fn.lastIndexOf(".");
  if(idx == -1) {
    return fn;
  }
  else return fn[0 .. idx];
}

version(Assembler) {
void main(string[] args) {
  string[] compiles;
  string[] inspects;
  string[] debugs;

  getopt(args,
      "compile|c", &compiles,
      "inspect|i", &inspects,
      "debugs|d", &debugs);



  foreach(file; compiles) {
    writeln("compiling " ~ file ~ "...");
    compile(withoutExt(file));
  }

  foreach(file; inspects) {
    CodeUnit c = fetch(withoutExt(file));
    writeln(c);
  }

  foreach(file; debugs) {
    writeln("compiling " ~ file ~ "...");
    compile(withoutExt(file));
    CodeUnit c = fetch(withoutExt(file));
    writeln(c);
  }
}
}
