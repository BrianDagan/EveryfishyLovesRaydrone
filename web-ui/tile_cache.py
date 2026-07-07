import math
import os
import threading
import urllib.request

TILES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tiles')
_lock = threading.Lock()
_MAX_TILES = 20000


def _tile_path(z, x, y):
    return os.path.join(TILES_DIR, str(z), str(x), f'{y}.jpg')


def _tile_exists(z, x, y):
    return os.path.exists(_tile_path(z, x, y))


def get_tile(z: int, x: int, y: int) -> bytes | None:
    path = _tile_path(z, x, y)
    if os.path.exists(path):
        with open(path, 'rb') as f:
            return f.read()

    url = f'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
    req = urllib.request.Request(url, headers={'User-Agent': 'EveryfishyLovesRaydrone/1.0'})
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = resp.read()
        if not data:
            return None
        with _lock:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            if not os.path.exists(path):
                with open(path, 'wb') as f:
                    f.write(data)
        return data
    except Exception:
        return None


def _clamp_lat(lat):
    return max(-85.05112878, min(85.05112878, lat))


def _clamp_lon(lon):
    return max(-180.0, min(179.999999, lon))


def _latlon_to_tile(lat, lon, z):
    lat = _clamp_lat(lat)
    lon = _clamp_lon(lon)
    n = 2 ** z
    xtile = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    ytile = int((1.0 - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi) / 2.0 * n)
    return max(0, min(n - 1, xtile)), max(0, min(n - 1, ytile))


def cache_area(lat: float, lon: float, radius_mi: float, zooms: list[int] | None = None) -> dict:
    if zooms is None:
        zooms = [12, 13, 14, 15, 16, 17, 18]

    radius_mi = max(0.0, float(radius_mi))
    lat_delta = radius_mi / 69.0
    cos_lat = max(0.01, abs(math.cos(math.radians(_clamp_lat(lat)))))
    lon_delta = radius_mi / (69.0 * cos_lat)
    min_lat, max_lat = lat - lat_delta, lat + lat_delta
    min_lon, max_lon = lon - lon_delta, lon + lon_delta

    cached = skipped = failed = total = 0
    stopped = False
    for z in zooms:
        z = int(z)
        x1, y1 = _latlon_to_tile(max_lat, min_lon, z)
        x2, y2 = _latlon_to_tile(min_lat, max_lon, z)
        for x in range(min(x1, x2), max(x1, x2) + 1):
            for y in range(min(y1, y2), max(y1, y2) + 1):
                if total >= _MAX_TILES:
                    stopped = True
                    break
                total += 1
                if _tile_exists(z, x, y):
                    skipped += 1
                    continue
                if get_tile(z, x, y) is None:
                    failed += 1
                else:
                    cached += 1
            if stopped:
                break
        if stopped:
            break

    return {'cached': cached, 'skipped': skipped, 'failed': failed, 'total': total}
