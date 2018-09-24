# SimplerCache

## Description

A very simple cache. It uses timers for the ttl and ets for the storage.
No extra lock system is used. Only ets and atomic replace is done, when expected.
Mostly wrapper around ets and kept very simple by using newer apis and recent erlang improvements.

Using property model testing and property tests to verify the cache via propcheck.

## Installation

[available in Hex](https://hex.pm/packages/simpler_cache), the package can be installed
by adding `simpler_cache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:simpler_cache, "~> 0.1.0"}
  ]
end
```

- Sample configs
```
config :simpler_cache,
  cache_name: :simpler_cache_test,
  global_ttl_ms: 100_000
```
