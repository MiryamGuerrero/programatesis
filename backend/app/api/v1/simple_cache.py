import time
import threading
import functools

_lock = threading.Lock()
_cache = {}


def _make_key(func, args, kwargs):
    parts = [getattr(func, '__module__', ''), getattr(func, '__name__', '')]
    for a in args:
        try:
            parts.append(repr(a))
        except Exception:
            parts.append(str(a))
    for k in sorted(kwargs.keys()):
        v = kwargs[k]
        try:
            parts.append(f"{k}={repr(v)}")
        except Exception:
            parts.append(f"{k}={str(v)}")
    return '|'.join(parts)


def cached(ttl: int = 10):
    """Simple in-memory TTL cache decorator for quick wins in dev.
    Not suitable for multi-process production.
    """
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            key = _make_key(func, args, kwargs)
            now = time.time()
            with _lock:
                entry = _cache.get(key)
                if entry and entry[1] > now:
                    return entry[0]
            result = func(*args, **kwargs)
            with _lock:
                _cache[key] = (result, now + ttl)
            return result
        return wrapper
    return decorator
