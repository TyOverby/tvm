module memory;

import std.stdio;
import std.conv;

import machinecode;
import machine;

/**
 * Instead of having a large chunk of memory for the machine, divide it up into blocks that 
 * are only allocated as needed.
 */
class Memory {
  enum size_t BUCKET_COUNT = 512;
  enum size_t ELE_PER_BUCKET = 128;

  Mem[][] buckets;
  bool[] bucketset;

  this(){
    this.buckets = new Mem[][BUCKET_COUNT];
    this.bucketset = new bool[BUCKET_COUNT];
  }

  size_t max() {
    return BUCKET_COUNT * ELE_PER_BUCKET;
  }

  Mem opIndex(size_t index) {
    size_t b_index = index / ELE_PER_BUCKET;
    size_t b_loc = index % ELE_PER_BUCKET;

    if(b_index > BUCKET_COUNT) {
      throw new Exception("Out of machine range" ~ to!string(b_index));
    }


    if(!bucketset[b_index]) {
      return cast(Mem) 0;
    }

    return buckets[b_index][b_loc];
  }

  Mem opIndexAssign(Mem value, size_t index) {
    size_t b_index = index / ELE_PER_BUCKET;
    size_t b_loc = index % ELE_PER_BUCKET;

    if(b_index > BUCKET_COUNT) {
      throw new Exception("Out of machine index range" ~ to!string(b_index));
    }

    if(!bucketset[b_index]) {
      buckets[b_index] = new Mem[ELE_PER_BUCKET];
      bucketset[b_index] = true;
    }

    buckets[b_index][b_loc] = value;
    return value;
  }

  // Slow, but only called on load.  Could be optimized.
  Mem[] opSliceAssign(Mem[] arr, size_t start, size_t end) {
    for(size_t i = start; i < end; i++) {
      this[i] = arr[i-start];
    }

    return arr;
  }
}
