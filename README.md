# jai-geohash

Geohashing functions for Jai. Only returns 64-bit integer formatted versions currently.

This is based on [geohash-int](https://github.com/yinqiwen/geohash-int) by yinquiwen.

## Notes
 * It seems dumb to offer a "regular" and a "fast" version when both are functionally equivalent. 
   Leaving both in for completeness of conversion for now, but the "regular" version should be removed.
 * It would make sense to have stringify and destringify options.
 * There seems to be a slight variation compared to the C version, where the 26-32nd bits drift slightly. Can't find a problem
   with the code, so it might come down to some compiler-level implementation differences. Or perhaps I just can't find it.


