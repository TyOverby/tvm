module test;

import cerealed;
import std.stdio;

struct Pair {
  string s1;
  int a;
}

/*
void main() {
  auto p = Pair("foo", 5);

  int[Pair] map;
  map[p] = 105;

  auto ser = new Cerealiser();
  ser ~= map;

  auto deser = new Decerealiser(ser.bytes);
  int[Pair] outcu = deser.value!(int[Pair]);
  writeln(outcu);
} */
