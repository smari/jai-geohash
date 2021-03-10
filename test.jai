// Geohash test

#load "module.jai";
#import "Basic";
#import "POSIX";

main :: () {
	test_1();
	test_2();
	test_3();
}


get_current_epoch_millis :: () -> u64 {
	timeValue: timeval;
    gettimeofday(*timeValue, null);
    ret : u64 = (cast(u64) timeValue.tv_sec) * 1000;
    ret += xx ((timeValue.tv_usec) / 1000);
    return ret;
}


test_1 :: () {
    hash, fast_hash : GeoHashBits;

    lat_range, lon_range : GeoHashRange;

    lat_range.max = 20037726.37;
    lat_range.min = -20037726.37;
    lon_range.max = 20037726.37;
    lon_range.min = -20037726.37;
    latitude := 9741705.20;
    longitude := 5417390.90;

    start, end: u64;

    start = get_current_epoch_millis();
    for 1..10000000 {
        hash = geohash_encode(lat_range, lon_range, latitude, longitude, 24);
    }
	end = get_current_epoch_millis();
    print("Cost %ms to encode\n", end - start);

    start = get_current_epoch_millis();
    for 1..10000000 {
        fast_hash = geohash_fast_encode(lat_range, lon_range, latitude, longitude, 24);
    }
    end = get_current_epoch_millis();
    print("Cost %ms to fast encode\n", end - start);

    area, area1: GeoHashArea;
    start = get_current_epoch_millis();
    for 1..10000000 {
        geohash_decode(lat_range, lon_range, hash, *area);
    }
    end = get_current_epoch_millis();
    print("Cost %ms to  decode\n", end - start);

    start = get_current_epoch_millis();
    for 1..10000000 {
        geohash_fast_decode(lat_range, lon_range, hash, *area1);
    }
    end = get_current_epoch_millis();
    print("Cost %ms to fast decode\n", end - start);
}

test_2 :: () {
    neighbors: GeoHashNeighbors;

    lat_range, lon_range: GeoHashRange;

    lat_range.max = 20037726.37;
    lat_range.min = -20037726.37;
    lon_range.max = 20037726.37;
    lon_range.min = -20037726.37;

    radius := 5000;
    latitude := 9741705.20;
    longitude := 5417390.90;

    hash := geohash_encode(lat_range, lon_range, latitude, longitude, 24);
    fast_hash := geohash_fast_encode(lat_range, lon_range, latitude, longitude, 24);
    hash_min := geohash_encode(lat_range, lon_range, latitude - radius, longitude - radius, 13);
    hash_max := geohash_encode(lat_range, lon_range, latitude + radius, longitude + radius, 13);
    hash_lt := geohash_encode(lat_range, lon_range, latitude + radius, longitude - radius, 13);
    hash_gr := geohash_encode(lat_range, lon_range, latitude - radius, longitude + radius, 13);

    print("## %\n", hash.bits);
    print("## %\n", fast_hash.bits);
    geohash_get_neighbors(hash, *neighbors);
    print("%\n", hash.bits);
    print("%\n", neighbors.east.bits);
    print("%\n", neighbors.west.bits);
    print("%\n", neighbors.south.bits);
    print("%\n", neighbors.north.bits);
    print("%\n", neighbors.north_west.bits);
    print("%\n", neighbors.north_east.bits);
    print("%\n", neighbors.south_east.bits);
    print("%\n", neighbors.south_west.bits);

    print("##%\n", hash_min.bits);
    print("##%\n", hash_max.bits);
    print("##%\n", hash_lt.bits);
    print("##%\n", hash_gr.bits);

    area, area1: GeoHashArea;
    geohash_decode(lat_range, lon_range, hash, *area);
    geohash_fast_decode(lat_range, lon_range, hash, *area1);
    print("% %\n", area.latitude.min, area.latitude.max);
    print("% %\n", area.longitude.min, area.longitude.max);
    print("% %\n", area1.latitude.min, area1.latitude.max);
    print("% %\n", area1.longitude.min, area1.longitude.max);
}

test_3 :: () {
    lat_range, lon_range: GeoHashRange;
    lat_range.max = 90.0;
    lat_range.min = -90.0;
    lon_range.max = 180.0;
    lon_range.min = -180.0;

    latitude  : float64 = 12.34;
    longitude : float64 = 56.78;

    for step:1..32 {
        hash := geohash_encode(lat_range, lon_range, latitude, longitude, xx step);
        fast_hash := geohash_fast_encode(lat_range, lon_range, latitude, longitude, xx step);

        print("normal encode (%): %\n", step, hash.bits);
        print("fast encode   (%): %\n", step, fast_hash.bits);
        print("\n");
    }
}
