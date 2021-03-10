
/*
 *  jai-geohash
 *
 *  Smári McCarthy, 2021.
 *  Based on geohash-int, Copyright (c) 2013, yinqiwen; https://github.com/yinqiwen/geohash-int
 */


GeoDirection :: enum {
    GEOHASH_NORTH       :: 0;
    GEOHASH_EAST        :: 1;
    GEOHASH_WEST        :: 2;
    GEOHASH_SOUTH       :: 3;
    GEOHASH_SOUTH_WEST  :: 4;
    GEOHASH_SOUTH_EAST  :: 5;
    GEOHASH_NORTH_WEST  :: 6;
    GEOHASH_NORTH_EAST  :: 7;
}

GeoHashBits :: struct {
    bits        : u64;
    step        : u8;
}

GeoHashRange :: struct {
    max         : float64;
    min         : float64;
}

GeoHashArea :: struct {
    hash        : GeoHashBits;
    latitude    : GeoHashRange;
    longitude   : GeoHashRange;
}

GeoHashNeighbors :: struct {
    north       : GeoHashBits;
    east        : GeoHashBits;
    west        : GeoHashBits;
    south       : GeoHashBits;
    north_east  : GeoHashBits;
    south_east  : GeoHashBits;
    north_west  : GeoHashBits;
    south_west  : GeoHashBits;
}


geohash_encode :: (lat_range_in: GeoHashRange, lon_range_in: GeoHashRange, latitude: float64, longitude: float64,
                   step: u8) -> GeoHashBits, bool {
    hash: GeoHashBits;
    if (step > 32 || step == 0)  return hash, false;

    lat_range := lat_range_in;
    lon_range := lon_range_in;

    hash.bits = 0;
    hash.step = step;

    if (latitude < lat_range.min || latitude > lat_range.max
     || longitude < lon_range.min || longitude > lon_range.max) {
        return hash, false;
    }

    for 0..step-1 {
        lat_bit: u8;
        lon_bit: u8;

        if (lat_range.max - latitude >= latitude - lat_range.min) {
            lat_bit = 0;
            lat_range.max = (lat_range.max + lat_range.min) / 2;
        } else {
            lat_bit = 1;
            lat_range.min = (lat_range.max + lat_range.min) / 2;
        }

        if (lon_range.max - longitude >= longitude - lon_range.min) {
            lon_bit = 0;
            lon_range.max = (lon_range.max + lon_range.min) / 2;
        } else {
            lon_bit = 1;
            lon_range.min = (lon_range.max + lon_range.min) / 2;
        }

        hash.bits <<= 1;
        hash.bits += lon_bit;
        hash.bits <<= 1;
        hash.bits += lat_bit;
    }
    return hash, true;
}


get_bit :: inline (bits: u64, pos: u8) -> u8 {
    return cast(u8) (bits >> pos) & 0x01;
}


geohash_decode :: (lat_range: GeoHashRange, lon_range: GeoHashRange, hash: GeoHashBits, area: *GeoHashArea) -> bool {
    if area == null {
        return false;
    }
    area.hash = hash;

    area.latitude.min = lat_range.min;
    area.latitude.max = lat_range.max;
    area.longitude.min = lon_range.min;
    area.longitude.max = lon_range.max;

    for i:0..hash.step-1 {
        lon_bit := get_bit(hash.bits, (hash.step - i) * 2 - 1);
        lat_bit := get_bit(hash.bits, (hash.step - i) * 2 - 2);

        if lat_bit == 0 {
            area.latitude.max = (area.latitude.max + area.latitude.min) / 2;
        } else {
            area.latitude.min = (area.latitude.max + area.latitude.min) / 2;
        }

        if lon_bit == 0 {
            area.longitude.max = (area.longitude.max + area.longitude.min) / 2;
        } else {
            area.longitude.min = (area.longitude.max + area.longitude.min) / 2;
        }
    }
    return true;
}


interleave64 :: inline (xlo: u32, ylo: u32) -> u64 {
    B :: u64.[ 0x5555555555555555, 0x3333333333333333, 0x0F0F0F0F0F0F0F0F, 0x00FF00FF00FF00FF, 0x0000FFFF0000FFFF ];
    S :: u64.[ 1, 2, 4, 8, 16 ];

    x : u64 = xlo; // Interleave lower  bits of x and y, so the bits of x
    y : u64 = ylo; // are in the even positions and bits from y in the odd; //https://graphics.stanford.edu/~seander/bithacks.html#InterleaveBMN

    // x and y must initially be less than 2**32.
    for < 4..0 {
        x = (x | (x << S[it])) & B[it];
        y = (y | (y << S[it])) & B[it];        
    }

    return x | (y << 1);
}

deinterleave64 :: inline (interleaved: u64) -> u64 {
    B :: u64.[ 0x5555555555555555, 0x3333333333333333, 0x0F0F0F0F0F0F0F0F, 0x00FF00FF00FF00FF, 0x0000FFFF0000FFFF, 0x00000000FFFFFFFF ];
    S :: u64.[ 0, 1, 2, 4, 8, 16 ];

    x := interleaved; ///reverse the interleave process (http://stackoverflow.com/questions/4909263/how-to-efficiently-de-interleave-bits-inverse-morton)
    y := interleaved >> 1;

    for 0..5 {
        x = (x | (x >> S[it])) & B[it];
        y = (y | (y >> S[it])) & B[it];        
    }

    return x | (y << 32);
}


geohash_fast_encode :: (lat_range: GeoHashRange, lon_range: GeoHashRange, latitude: float64, longitude: float64, step: u8) -> GeoHashBits, bool {
    hash : GeoHashBits;
    if (step > 32 || step == 0)  return hash, false;
    
    hash.bits = 0;
    hash.step = step;
    if   (latitude < lat_range.min || latitude > lat_range.max
      || longitude < lon_range.min || longitude > lon_range.max) {
        return hash, false;
    }

    // The algorithm computes the morton code for the geohash location within
    // the range this can be done MUCH more efficiently using the following code

    //compute the coordinate in the range 0-1
    lat_offset : float64 = (latitude - lat_range.min) / (lat_range.max - lat_range.min);
    lon_offset : float64 = (longitude - lon_range.min) / (lon_range.max - lon_range.min);

    //convert it to fixed point based on the step size
    lat_offset *= (1 << step);
    lon_offset *= (1 << step);

    ilato := cast(u32) lat_offset;
    ilono := cast(u32) lon_offset;

    //interleave the bits to create the morton code.  No branching and no bounding
    hash.bits = interleave64(ilato, ilono);
    return hash, true;
}


geohash_fast_decode :: (lat_range: GeoHashRange, lon_range: GeoHashRange, hash: GeoHashBits, area: *GeoHashArea) -> bool {
    if area == null  return false;

    area.hash = hash;
    step := hash.step;
    xyhilo := deinterleave64(hash.bits); //decode morton code

    lat_scale := lat_range.max - lat_range.min;
    lon_scale := lon_range.max - lon_range.min;

    ilato : u32 = cast,no_check(u32) xyhilo;        //get back the original integer coordinates
    ilono : u32 = cast,no_check(u32) xyhilo >> 32;

    area.latitude.min = lat_range.min + (ilato * 1.0 / (1 << step)) * lat_scale;
    area.latitude.max = lat_range.min + ((ilato + 1) * 1.0 / (1 << step)) * lat_scale;
    area.longitude.min = lon_range.min + (ilono * 1.0 / (1 << step)) * lon_scale;
    area.longitude.max = lon_range.min + ((ilono + 1) * 1.0 / (1 << step)) * lon_scale;

    return true;
}


geohash_move_x :: (hash: *GeoHashBits, d: s8) {
    if d == 0  return;
    x := hash.bits & 0xaaaaaaaaaaaaaaaa;
    y := hash.bits & 0x5555555555555555;

    zz : u64 = xx (0x5555555555555555 >> (64 - hash.step * 2));
    if d > 0 {
        x = x + (zz + 1);
    } else {
        x = x | zz;
        x = x - (zz + 1);
    }
    x &= xx (0xaaaaaaaaaaaaaaaa >> (64 - hash.step * 2));
    hash.bits = (x | y);
    return;
}


geohash_move_y :: (hash: *GeoHashBits, d: s8) {
    if d == 0  return;
    x := hash.bits & 0xaaaaaaaaaaaaaaaa;
    y := hash.bits & 0x5555555555555555;

    zz : u64 = xx (0xaaaaaaaaaaaaaaaa >> (64 - hash.step * 2));
    if (d > 0) {
        y = y + (zz + 1);
    } else {
        y = y | zz;
        y = y - (zz + 1);
    }
    y &= xx (0x5555555555555555 >> (64 - hash.step * 2));
    hash.bits = (x | y);
    return;
}

geohash_get_neighbors :: (hash: GeoHashBits, neighbors: *GeoHashNeighbors) {
    neighbors.north      = geohash_get_neighbor(hash, .GEOHASH_NORTH);
    neighbors.east       = geohash_get_neighbor(hash, .GEOHASH_EAST);
    neighbors.west       = geohash_get_neighbor(hash, .GEOHASH_WEST);
    neighbors.south      = geohash_get_neighbor(hash, .GEOHASH_SOUTH);
    neighbors.south_west = geohash_get_neighbor(hash, .GEOHASH_SOUTH_WEST);
    neighbors.south_east = geohash_get_neighbor(hash, .GEOHASH_SOUTH_EAST);
    neighbors.north_west = geohash_get_neighbor(hash, .GEOHASH_NORTH_WEST);
    neighbors.north_east = geohash_get_neighbor(hash, .GEOHASH_NORTH_EAST);
}

geohash_get_neighbor :: (hash: GeoHashBits, direction: GeoDirection) -> GeoHashBits {
    neighbor := hash;
    if direction == {
        case .GEOHASH_NORTH; {
            geohash_move_x(*neighbor, 0);
            geohash_move_y(*neighbor, 1);
        }
        case .GEOHASH_SOUTH; {
            geohash_move_x(*neighbor, 0);
            geohash_move_y(*neighbor, -1);
        }
        case .GEOHASH_EAST;  {
            geohash_move_x(*neighbor, 1);
            geohash_move_y(*neighbor, 0);
        }
        case .GEOHASH_WEST;  {
            geohash_move_x(*neighbor, -1);
            geohash_move_y(*neighbor, 0);
        }
        case .GEOHASH_SOUTH_WEST; {
            geohash_move_x(*neighbor, -1);
            geohash_move_y(*neighbor, -1);
        }
        case .GEOHASH_SOUTH_EAST; {
            geohash_move_x(*neighbor, 1);
            geohash_move_y(*neighbor, -1);
        }
        case .GEOHASH_NORTH_WEST; {
            geohash_move_x(*neighbor, -1);
            geohash_move_y(*neighbor, 1);
        }
        case .GEOHASH_NORTH_EAST; {
            geohash_move_x(*neighbor, 1);
            geohash_move_y(*neighbor, 1);
        }
    }
    return neighbor;
}

geohash_next_leftbottom :: (bits: GeoHashBits) -> GeoHashBits {
    newbits := bits;
    newbits.step += 1;
    newbits.bits <<= 2;
    return newbits;
}

geohash_next_rightbottom :: (bits: GeoHashBits) -> GeoHashBits {
    newbits := bits;
    newbits.step += 1;
    newbits.bits <<= 2;
    newbits.bits += 2;
    return newbits;
}

geohash_next_lefttop :: (bits: GeoHashBits) -> GeoHashBits {
    newbits := bits;
    newbits.step += 1;
    newbits.bits <<= 2;
    newbits.bits += 1;
    return newbits;
}

geohash_next_righttop :: (bits: GeoHashBits) -> GeoHashBits {
    newbits := bits;
    newbits.step += 1;
    newbits.bits <<= 2;
    newbits.bits += 3;
    return newbits;
}
