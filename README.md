# SimpleCache

**TODO: Add description**

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

table_name = Application.get_env(:simple_cache, :cache_name, :simple_cache)
ttl_sec = Application.get_env(:simple_cache, :global_ttl_sec, 30)

A very simple cache. It uses timers for the ttl and ets for the storage.
No locks are built for ets and atomic replace is done, when expected.
Model and property testing are used to verify things.
Mostly wrapper around ets and kept very simple by using newer apis and recent erlang improvements.

