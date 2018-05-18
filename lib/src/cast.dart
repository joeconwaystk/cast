library cast;

import 'dart:async' as async;
import 'dart:core' as core;
import 'dart:core' hide Map, String, int;

class FailedCast implements core.Exception {
  dynamic context;
  dynamic key;
  core.String message;
  FailedCast(this.context, this.key, this.message);
  toString() {
    if (key == null) {
      return "Failed cast at $context: $message";
    }
    return "Failed cast at $context $key: $message";
  }
}

abstract class Cast<T> {
  const Cast();
  T _cast(dynamic from, core.String context, dynamic key);
  T cast(dynamic from) => _cast(from, "toplevel", null);
}

class AnyCast extends Cast<dynamic> {
  const AnyCast();
  dynamic _cast(dynamic from, core.String context, dynamic key) => from;
}

class IntCast extends Cast<core.int> {
  const IntCast();
  core.int _cast(dynamic from, core.String context, dynamic key) =>
      from is core.int
          ? from
          : throw new FailedCast(context, key, "$from is not an int");
}

class DoubleCast extends Cast<core.double> {
  const DoubleCast();
  core.double _cast(dynamic from, core.String context, dynamic key) =>
      from is core.double
          ? from
          : throw new FailedCast(context, key, "$from is not an double");
}

class StringCast extends Cast<core.String> {
  const StringCast();
  core.String _cast(dynamic from, core.String context, dynamic key) =>
      from is core.String
          ? from
          : throw new FailedCast(context, key, "$from is not a String");
}

class BoolCast extends Cast<core.bool> {
  const BoolCast();
  core.bool _cast(dynamic from, core.String context, dynamic key) =>
      from is core.bool
          ? from
          : throw new FailedCast(context, key, "$from is not a bool");
}

class Map<K, V> extends Cast<core.Map<K, V>> {
  final Cast<K> _key;
  final Cast<V> _value;
  const Map(Cast<K> key, Cast<V> value)
      : _key = key,
        _value = value;
  core.Map<K, V> _cast(dynamic from, core.String context, dynamic key) {
    if (from is core.Map) {
      var result = <K, V>{};
      for (var key in from.keys) {
        var newKey = _key._cast(key, "map entry", key);
        result[newKey] = _value._cast(from[key], "map entry", key);
      }
      return result;
    }
    return throw new FailedCast(context, key, "not a map");
  }
}

class StringMap<V> extends Cast<core.Map<core.String, V>> {
  final Cast<V> _value;
  const StringMap(Cast<V> value) : _value = value;
  core.Map<core.String, V> _cast(
      dynamic from, core.String context, dynamic key) {
    if (from is core.Map) {
      var result = <core.String, V>{};
      for (core.String key in from.keys) {
        result[key] = _value._cast(from[key], "map entry", key);
      }
      return result;
    }
    return throw new FailedCast(context, key, "not a map");
  }
}

class List<E> extends Cast<core.List<E>> {
  final Cast<E> _entry;
  const List(Cast<E> entry) : _entry = entry;
  core.List<E> _cast(dynamic from, core.String context, dynamic key) {
    if (from is core.List) {
      var length = from.length;
      var result = core.List<E>(length);
      for (core.int i = 0; i < length; ++i) {
        result[i] = _entry._cast(from[i], "list entry", i);
      }
      return result;
    }
    return throw new FailedCast(context, key, "not a list");
  }
}

class Keyed<K, V> extends Cast<core.Map<K, V>> {
  final core.Map<K, Cast<V>> _map;
  final Cast<V> _otherwise;
  const Keyed(core.Map<K, Cast<V>> map, {Cast<V> otherwise})
      : _map = map,
        _otherwise = otherwise;
  core.Map<K, V> _cast(dynamic from, core.String context, dynamic key) {
    core.Map<K, V> result = {};
    if (from is core.Map) {
      for (K key in from.keys) {
        var entry = _map[key] ?? _otherwise;
        if (entry == null)
          throw new FailedCast("map entry", key, "key not found");
        result[key] = entry._cast(from[key], "map entry", key);
      }
      return result;
    }
    return throw new FailedCast(context, key, "not a map");
  }
}

class OneOf<S, T> extends Cast<dynamic> {
  final Cast<S> _left;
  final Cast<T> _right;
  const OneOf(Cast<S> left, Cast<T> right)
      : _left = left,
        _right = right;
  dynamic _cast(dynamic from, core.String context, dynamic key) {
    try {
      return _left._cast(from, context, key);
    } on FailedCast {
      return _right._cast(from, context, key);
    }
  }
}

class Apply<S, T> extends Cast<T> {
  final Cast<S> _first;
  final T Function(S) _transform;
  const Apply(T Function(S) transform, Cast<S> first)
      : _transform = transform,
        _first = first;
  T _cast(dynamic from, core.String context, dynamic key) =>
      _transform(_first._cast(from, context, key));
}

class Future<E> extends Cast<async.Future<E>> {
  final Cast<E> _value;
  const Future(Cast<E> value) : _value = value;
  async.Future<E> _cast(dynamic from, core.String context, dynamic key) {
    if (from is async.Future) {
      return from.then(_value.cast);
    }
    return throw new FailedCast(context, key, "not a Future");
  }
}

const any = AnyCast();
const bool = BoolCast();
const int = IntCast();
const double = DoubleCast();
const String = StringCast();
