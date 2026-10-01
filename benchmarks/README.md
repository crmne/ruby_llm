# Benchmarks

These scripts measure RubyLLM's own overhead: connections, streaming, request rendering, memory, the model registry, and the Rails integration. They make no network calls and need no API keys. Providers answer through a canned Faraday adapter, a loopback HTTPS server, or a simulated token endpoint, so every run parses the same bytes.

Run every area, or one, against this checkout:

```sh
bundle exec rake benchmark
bundle exec rake "benchmark[streaming]"
```

Compare a released version with this checkout:

```sh
bundle exec rake "benchmark:compare[v2.0.0]"
bundle exec rake "benchmark:compare[v2.0.0,connections]"
```

The comparison exports `lib/` and `spec/dummy/` of the git ref to a temporary directory and runs the same scripts against it, so a version older than these benchmarks can be measured too. Set `BENCH_REF` to run `rake benchmark` against a ref on its own. To run one script by hand against any checkout, point `BENCH_ROOT` at it:

```sh
BUNDLE_GEMFILE=benchmarks/Gemfile BENCH_ROOT=../ruby_llm-2.0 bundle exec ruby benchmarks/streaming.rb
```

| Area | Measures |
| --- | --- |
| `connections` | TLS handshakes and time per call for `:net_http`, `:net_http_persistent`, and `:async_http`, from one thread, four threads, tenant contexts, and Async reactors |
| `vertex_ai` | OAuth token requests and time per call for Vertex AI with a service account key, against a token endpoint with 50 ms of latency (`BENCH_TOKEN_LATENCY_MS`) |
| `streaming` | Streams of 500 and 20,000 deltas in each protocol, a 2 MB event split across reads, long reasoning, and citations repeated on every chunk |
| `requests` | Asks that resend a chat's history, ten tools, a 2.4 MB embeddings response, and a Bedrock history carrying a 2 MB image |
| `memory` | The heap a 40-turn chat with a 256 KB image keeps after a full GC |
| `registry` | Threads loading the model registry at the same time |
| `transcript` | Queries and time to rebuild a persisted 100-message chat, with `automatic_scope_inversing` on and off |
| `attachments` | Active Storage downloads when loading and asking a chat with ten 1 MB images |
| `provider_files` | Uploads, downloads, and time for later turns of a chat with a 30 MB PDF, each in a new process |

Each case reports the median of several runs and the range they spanned, after warmup. Cases that need the state of a new process, such as a cold registry or a fresh connection pool, fork one per run. Set `BENCH_RUNS` to change the number of runs, and `BENCH_ROUNDS` to alternate between the two versions of a comparison several times, so changes in the machine's load reach both.

The connection benchmark runs on loopback, where a handshake costs only CPU time; across a network, each handshake also costs round trips.

The scripts run in their own bundle, `benchmarks/Gemfile`, which adds the keep-alive adapters, and a gem the 2.0.0 dummy app loads, to the development bundle. The rake tasks install it. Times depend on the machine; compare versions on the same machine in the same session, and treat differences within the reported ranges as noise.
