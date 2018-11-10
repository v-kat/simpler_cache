defmodule BenchmarkHelpers do
  def async_times(times, input_fn) do
    fn ->
        1..times
      |> Enum.map(fn _x -> Task.async(input_fn) end)
      |> Enum.map(&Task.await/1)
    end
  end

  def init() do
    Cachex.start_link(:cachex_cache, [interval: nil])
    ConCache.start_link(name: :con_cache, ttl_check_interval: :timer.seconds(2), global_ttl: 10_000)
  end

  def insert() do
    Cachex.put(:cachex_cache, "key", "test_value")
    ConCache.put(:con_cache, "key", "test_value")
    SimplerCache.put("key", "test_value")
  end
end

key_to_save = %{map: %{with: 1234, nested: "data of things"}, for: "more real", world: 5678, data: 90}

store_fn = fn () -> key_to_save end
cachex_ttl = 10_000

BenchmarkHelpers.init()
# BenchmarkHelpers.insert()

Benchee.run(%{
  "cachex_cache_10" => BenchmarkHelpers.async_times(10, fn -> Cachex.fetch(:cachex_cache, "key", store_fn, ttl: cachex_ttl) end),
  "con_cache_10" => BenchmarkHelpers.async_times(10, fn -> ConCache.get_or_store(:con_cache, "key", store_fn) end),
  "simpler_cache_10" => BenchmarkHelpers.async_times(10, fn -> SimplerCache.get_or_store("key", store_fn) end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/10/results.html"]])

Benchee.run(%{
  "cachex_cache_100" => BenchmarkHelpers.async_times(100, fn -> Cachex.fetch(:cachex_cache, "key", store_fn, ttl: cachex_ttl) end),
  "con_cache_100" => BenchmarkHelpers.async_times(100, fn -> ConCache.get_or_store(:con_cache, "key", store_fn) end),
  "simpler_cache_100" => BenchmarkHelpers.async_times(100, fn -> SimplerCache.get_or_store("key", store_fn) end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/100/results.html"]])

Benchee.run(%{
  "cachex_cache_500" => BenchmarkHelpers.async_times(500, fn -> Cachex.fetch(:cachex_cache, "key", store_fn, ttl: cachex_ttl) end),
  "con_cache_500" => BenchmarkHelpers.async_times(500, fn -> ConCache.get_or_store(:con_cache, "key", store_fn) end),
  "simpler_cache_500" => BenchmarkHelpers.async_times(500, fn -> SimplerCache.get_or_store("key", store_fn) end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/500/results.html"]])

Benchee.run(%{
  "cachex_cache_1_000" => BenchmarkHelpers.async_times(1_000, fn -> Cachex.fetch(:cachex_cache, "key", store_fn, ttl: cachex_ttl) end),
  "con_cache_1_000" => BenchmarkHelpers.async_times(1_000, fn -> ConCache.get_or_store(:con_cache, "key", store_fn) end),
  "simpler_cache_1_000" => BenchmarkHelpers.async_times(1_000, fn -> SimplerCache.get_or_store("key", store_fn) end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/1000/results.html"]])
