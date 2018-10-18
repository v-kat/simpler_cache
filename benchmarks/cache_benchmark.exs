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
    ConCache.start_link(name: :con_cache, ttl_check_interval: false)
  end

  def insert() do
    Cachex.put(:cachex_cache, "key", "test_value")
    ConCache.put(:con_cache, "key", "test_value")
    SimplerCache.put("key", "test_value")
  end
end

BenchmarkHelpers.init()
BenchmarkHelpers.insert()

Benchee.run(%{
  "cachex_cache_10" => BenchmarkHelpers.async_times(10, fn -> Cachex.get(:cachex_cache, "key") end),
  "con_cache_10" => BenchmarkHelpers.async_times(10, fn -> ConCache.get(:con_cache, "key") end),
  "simpler_cache_10" => BenchmarkHelpers.async_times(10, fn -> SimplerCache.get("key") end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/10/results.html"]])

Benchee.run(%{
  "cachex_cache_100" => BenchmarkHelpers.async_times(100, fn -> Cachex.get(:cachex_cache, "key") end),
  "con_cache_100" => BenchmarkHelpers.async_times(100, fn -> ConCache.get(:con_cache, "key") end),
  "simpler_cache_100" => BenchmarkHelpers.async_times(100, fn -> SimplerCache.get("key") end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/100/results.html"]])

Benchee.run(%{
  "cachex_cache_1000" => BenchmarkHelpers.async_times(1_000, fn -> Cachex.get(:cachex_cache, "key") end),
  "con_cache_1000" => BenchmarkHelpers.async_times(1_000, fn -> ConCache.get(:con_cache, "key") end),
  "simpler_cache_1000" => BenchmarkHelpers.async_times(1_000, fn -> SimplerCache.get("key") end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/1000/results.html"]])

Benchee.run(%{
  "cachex_cache_4_000" => BenchmarkHelpers.async_times(4_000, fn -> Cachex.get(:cachex_cache, "key") end),
  "con_cache_4_000" => BenchmarkHelpers.async_times(4_000, fn -> ConCache.get(:con_cache, "key") end),
  "simpler_cache_4_000" => BenchmarkHelpers.async_times(4_000, fn -> SimplerCache.get("key") end)
},
  time: 15,
  warmup: 5,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  formatter_options: [html: [file: "benchmarks/output/10000/results.html"]])
