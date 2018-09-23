# SimpleCache

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `simple_cache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:simple_cache, "~> 0.1.0"}
  ]
end
```

- Sample configs
```
config :simple_cache,
  cache_name: :simple_cache_test,
  global_ttl_ms: 100_000
```

## Description

A very simple cache. It uses timers for the ttl and ets for the storage.
No locks are built upon for ets and atomic replace is done, when expected.
Mostly wrapper around ets and kept very simple by using newer apis and recent erlang improvements.

Using property model testing and property tests to verify the cache via propcheck.

