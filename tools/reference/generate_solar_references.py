#!/usr/bin/env python3
"""Generate reference values for the GoldenHour solar engine tests.

Reference: Skyfield (https://rhodesmill.org/skyfield/) with the JPL DE421 planetary
ephemeris, shipped in the `skyfield-data` package so no network access is needed.
Skyfield computes the apparent topocentric position of the Sun (light time, aberration,
deflection, precession-nutation IAU 2000A) and is accurate to well under 1 arc-second,
i.e. two to three orders of magnitude better than the Meeus low-accuracy algorithm
implemented in the app. It is therefore a suitable "ground truth".

Conventions matched to the app engine:
  * elevation = geometric (airless) altitude of the Sun's centre, observer at sea level (WGS84);
  * sunrise/sunset threshold -0.8333 deg, twilights -6/-12/-18, golden/blue hour -4 and +6;
  * events are reported for the *local* calendar day of the place (IANA time zone).

Usage:
    python3 -m venv .venv && .venv/bin/pip install skyfield skyfield-data
    .venv/bin/python tools/reference/generate_solar_references.py \
        > Packages/GoldenHourKit/Tests/SolarEngineTests/Fixtures/skyfield_reference.json
"""
import json
import os
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import skyfield_data
from skyfield import almanac
from skyfield.api import Loader, wgs84
from skyfield.searchlib import find_discrete

DATA_DIR = os.path.join(os.path.dirname(skyfield_data.__file__), "data")
load = Loader(DATA_DIR)
ts = load.timescale(builtin=True)
eph = load("de421.bsp")
earth, sun = eph["earth"], eph["sun"]

THRESHOLDS = [-18.0, -12.0, -6.0, -4.0, -0.8333, 6.0]

PLACES = [
    # name, latitude, longitude, IANA zone
    ("Paris", 48.8566, 2.3522, "Europe/Paris"),
    ("New York", 40.7128, -74.0060, "America/New_York"),
    ("Los Angeles", 34.0522, -118.2437, "America/Los_Angeles"),
    ("Quito", -0.1807, -78.4678, "America/Guayaquil"),
    ("Singapore", 1.3521, 103.8198, "Asia/Singapore"),
    ("Sydney", -33.8688, 151.2093, "Australia/Sydney"),
    ("Cape Town", -33.9249, 18.4241, "Africa/Johannesburg"),
    ("Tokyo", 35.6762, 139.6503, "Asia/Tokyo"),
    ("Reykjavik", 64.1466, -21.9426, "Atlantic/Reykjavik"),
    ("Ushuaia", -54.8019, -68.3030, "America/Argentina/Ushuaia"),
    ("Tromso", 69.6492, 18.9553, "Europe/Oslo"),
    ("Longyearbyen", 78.2232, 15.6267, "Arctic/Longyearbyen"),
    ("Kiritimati", 1.8721, -157.4278, "Pacific/Kiritimati"),
]

DATES = [
    "2026-03-20",  # March equinox
    "2026-06-21",  # June solstice
    "2026-09-23",  # September equinox
    "2026-12-21",  # December solstice
    "2026-03-08",  # US DST start
    "2026-03-29",  # EU DST start
    "2026-10-25",  # EU DST end
    "2026-11-01",  # US DST end
    "2026-04-05",  # Australian DST end
    "1990-07-15",  # past date
    "2045-02-10",  # future date
]


def local_day_bounds(date_str, zone):
    y, m, d = map(int, date_str.split("-"))
    tz = ZoneInfo(zone)
    start = datetime(y, m, d, tzinfo=tz)
    end = (start + timedelta(days=1)).replace(tzinfo=tz)
    # Re-anchor through calendar arithmetic so DST days are 23/25 h long.
    end = datetime(end.year, end.month, end.day, tzinfo=tz)
    return start.astimezone(timezone.utc), end.astimezone(timezone.utc)


def iso(t):
    return t.utc_datetime().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def altaz(observer, t):
    alt, az, _ = observer.at(t).observe(sun).apparent().altaz()
    return alt.degrees, az.degrees


def main():
    cases = []
    for name, lat, lon, zone in PLACES:
        topos = wgs84.latlon(lat, lon)
        observer = earth + topos
        for date_str in DATES:
            start, end = local_day_bounds(date_str, zone)
            t0, t1 = ts.from_datetime(start), ts.from_datetime(end)
            crossings = {}
            for thr in THRESHOLDS:
                def above(t, thr=thr):
                    return altaz(observer, t)[0] >= thr
                above.step_days = 1 / 720  # 2 minutes
                times, values = find_discrete(t0, t1, above, epsilon=0.1 / 86400)
                crossings[repr(thr)] = [
                    {"date": iso(t), "rising": bool(v)} for t, v in zip(times, values)
                ]
            f = almanac.meridian_transits(eph, sun, topos)
            times, values = find_discrete(t0, t1, f, epsilon=0.1 / 86400)
            noons = [iso(t) for t, v in zip(times, values) if v == 1]
            samples = []
            for k in range(1, 8):
                t = ts.from_datetime(start + timedelta(hours=3 * k))
                alt, az = altaz(observer, t)
                samples.append({"date": iso(t), "elevation": alt, "azimuth": az})
            cases.append({
                "place": name, "latitude": lat, "longitude": lon, "timeZone": zone,
                "date": date_str, "crossings": crossings, "solarNoons": noons,
                "positions": samples,
            })
    print(json.dumps({
        "generator": "Skyfield + JPL DE421 (tools/reference/generate_solar_references.py)",
        "thresholds": THRESHOLDS,
        "cases": cases,
    }, indent=1))


if __name__ == "__main__":
    main()
