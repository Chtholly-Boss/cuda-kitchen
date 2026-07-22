---
name: bench-kernel
description: "CUDA kernel microbenchmarking with bench_kineto (torch.profiler/Kineto-based per-kernel timing) and bench (wall-clock event-based) utilities. Use when measuring a CUDA kernel's latency, comparing kernel variants, computing TFLOPS, isolating per-kernel GPU time from CPU launch overhead, or running GEMM/attention/conv benchmarks. Triggers on benchmark, bench_kineto, kernel timing, microbenchmark, TFLOPS measurement, GEMM bench, per-kernel timing, profiler.schedule, torch.profiler."
---

# bench-kernel Skill

Microbenchmark a CUDA kernel — measure its latency and compute TFLOPS, isolating GPU time from CPU launch overhead. Uses two utilities from DeepGEMM's `deep_gemm/testing/bench.py`, vendored as [`bench.py`](bench.py) in this skill.

**Canonical upstream:** <https://github.com/deepseek-ai/DeepGEMM/blob/main/deep_gemm/testing/bench.py>

## What this skill is for

- "How long does kernel X take?" — per-kernel latency, isolated from launch overhead
- "What TFLOPS does this GEMM hit?" — FLOPS / time, with correct shape-aware denominator
- "Is kernel A faster than kernel B?" — apples-to-apples comparison by kernel name
- "Of the N kernels my function launches, which dominates?" — per-kernel breakdown

## What this skill is NOT for

- End-to-end app profiling → use `nsys` (see the `cuda` skill)
- Kernel-internal bottlenecks (stalls, occupancy, roofline) → use `ncu`
- Triton / torch.compile kernel dev iteration → those have their own bench tooling

## bench vs bench_kineto — when to use which

**Default to `bench_kineto`.** It uses `torch.profiler` (Kineto) to extract per-kernel CUDA time from the profiler table, so it measures **only the GPU time of the named kernel(s)**, not the surrounding Python/launch overhead.

Use `bench` (wall-clock via `torch.cuda.Event`) only when:
- You want a quick sanity check and don't care about per-kernel breakdown
- The function under test is exactly one kernel and CPU launch overhead is negligible relative to kernel time (typically kernel > 1ms)
- You're blocked from running the profiler (rare)

| Situation | Use |
|-----------|-----|
| Function launches multiple kernels | `bench_kineto` (gives per-kernel breakdown) |
| Need to compare kernel variants by name | `bench_kineto` |
| Kernel time < 100 µs (launch overhead matters) | `bench_kineto` |
| Quick "does this even work" smoke test | `bench` |
| Running under `nsys` / `ncu` / `compute-sanitizer` | neither — `bench_kineto` uses `torch.profiler` which conflicts with those tools. Let the external tool capture kernel time directly, or fall back to `bench` for a wall-clock reading. |

## Reference implementation

The two utilities live in [`bench.py`](bench.py) next to this file. Two ways to use them:

```python
# Option A — copy bench.py into your project, then import
from bench import bench_kineto, bench

# Option B — sys.path trick if you want to use it in-place
import sys; sys.path.insert(0, '/path/to/.claude/skills/bench-kernel')
from bench import bench_kineto, bench
```

Signatures (see [`bench.py`](bench.py) for full source):

```python
bench(fn: Callable, num_warmups: int = 5, num_tests: int = 10,
      high_precision: bool = False) -> float  # seconds

bench_kineto(fn: Callable, kernel_names: str | tuple[str, ...],
             num_tests: int = 30, suppress_kineto_output: bool = False,
             trace_path: str | None = None, flush_l2: bool = True,
             with_multiple_kernels: bool = False,
             barrier: Callable | None = None) -> float | tuple[float, ...]  # seconds
```

> **Version drift.** The vendored [`bench.py`](bench.py) tracks DeepGEMM's `main` branch. Deployed containers often ship an older/forked copy. Common differences in the wild:
> - `barrier` parameter absent in older versions
> - `acc_events=True` absent in older versions (produces a "Profiler clears events" warning but still works)
> - schedule: `(wait=0, warmup=1, active=1)` (newer) vs `(wait=1, warmup=0, active=1)` (older)
> - older versions check env vars to skip profiling under nsight; this copy does not
>
> If a container has its own `deep_gemm.testing.bench`, prefer that copy and check its signature: `python -c "import deep_gemm.testing.bench as b; print(b.__file__); import inspect; print(inspect.signature(b.bench_kineto))"`.

## Workflow

### 1. Identify the kernel name(s) first

`bench_kineto` filters the profiler table by substring match, so you need the name(s) of the kernel(s) you care about. Options, in order of reliability:

```bash
# From a compiled binary/object (most reliable)
cuobjdump -sass ./your_binary | grep '@%fakecall' | sort -u
cuobjdump -sass ./your_binary | grep -E '\.text\.' | sort -u

# From source (if the kernel is written in CUDA C/Triton)
grep -rn '__global__' src/
TRITON_CACHE_DIR=./tri_cache python -c "..."   # Triton dumps under ~/.triton/cache

# By listing once with torch.profiler before doing the real bench
python -c "
import torch, your_kernel
prof = torch.profiler.profile(activities=[torch.profiler.ProfilerActivity.CUDA])
with prof:
    for _ in range(5): your_kernel.run()
print(prof.key_averages().table(sort_by='cuda_time_total', max_name_column_width=120))
"
```

The `kernel_names` argument accepts a `str` (one kernel) or a `tuple` of strings. Return type mirrors the input: scalar vs tuple.

### 2. Build the harness

```python
import torch
from bench import bench_kineto   # from this skill's bench.py

M, N, K = 4096, 4096, 4096
a = torch.randn(M, K, device='cuda', dtype=torch.bfloat16)
b = torch.randn(K, N, device='cuda', dtype=torch.bfloat16)

def fn():
    your_gemmlib.run(a, b)

t = bench_kineto(fn, kernel_names="your_kernel_substring", num_tests=30)
tflops = 2 * M * N * K / t / 1e12
print(f"{t*1e6:.1f} us, {tflops:.1f} TFLOPS")
```

### 3. Environment variables

| Variable | When to set |
|----------|-------------|
| `CUDA_VISIBLE_DEVICES=0` | Pin to a specific GPU in a multi-GPU box. |
| `TORCHINDUCTOR_BENCHMARK=1` | If the kernel comes from `torch.compile`. |

### 4. Compute TFLOPS correctly

For GEMM `C[M,N] = A[M,K] @ B[K,N]`:

```python
flops = 2 * M * N * K   # 2 because multiply-add = 2 ops
tflops = flops / t_seconds / 1e12
```

Cast to `float` (Python int) before dividing — for large shapes `2*M*N*K` can overflow int32. The formula above is safe in Python (arbitrary-precision int), but in C++/numba use `int64_t` or `double`.

For non-GEMM kernels, count FLOPS from the algorithm (e.g., attention = `4 * seq^2 * hidden * num_heads`-ish — be precise).

## Pitfalls

1. **CPU launch overhead dominates small kernels.** A kernel that takes 10 µs on GPU but 30 µs to launch will report ~30 µs via `bench()` (wall-clock) but ~10 µs via `bench_kineto()` (per-kernel). This is why the skill prefers Kineto.
2. **L2 cache warming.** Back-to-back iterations hit a warm L2, inflating throughput. `bench_kineto` flushes L2 with an 8 GB memset between iterations by default. If your GPU has >80 MB L2 (H100 ≈ 50 MB, B200 ≈ 96 MB), even 8 GB may be excessive — keep the default, the cost is constant.
3. **Profiler conflict.** `torch.profiler` cannot run alongside `nsys`/`ncu`/`compute-sanitizer`. When using those tools, skip `bench_kineto` — let the external tool capture kernel time directly, or use `bench` for a wall-clock reading.
4. **Multiple kernels with the same name.** If `with_multiple_kernels=False` (default), `bench_kineto` asserts that the kernel name appears at most once in the table. If your autotuner produces several variants with overlapping names, pass `with_multiple_kernels=True`.
5. **Wrong kernel name → silent zero.** If the substring doesn't match any line in the profiler table, `bench_kineto` returns 0.0 (divide-by-zero in TFLOPS). Always print `t` first.
6. **Auto-tuning prints pollute stdout.** Pass `suppress_kineto_output=True` to silence the autotuner during profiling.
7. **Asymmetric launch imbalance** (one CPU thread launching faster than another). If you see high variance, pass `barrier=some_callable` — `bench_kineto` calls `torch.cuda._sleep(2e7)` (~10 ms) + your barrier before each `fn()` to let the slower side catch up.

## DeepGEMM bf16 GEMM example

DeepGEMM exposes bf16 GEMM by layout suffix: `bf16_gemm_{nn,nt,tn,tt}`. All four are **in-place into a pre-allocated output** `d` — they do not return a tensor. Signature (from a 2025-Q3 container):

```
bf16_gemm_nt(a: Tensor[M, K], b: Tensor[N, K], d: Tensor[M, N], c?: Tensor = None, compiled_dims: str = "")
```

Note the `nt` layout: A is `[M, K]`, B is `[N, K]` (transposed — K is the reduction dim, both inputs have K as inner). Verify with a quick probe if unsure — calling with wrong shapes gives a clear C++ error message.

```python
import torch
import deep_gemm
from bench import bench_kineto   # this skill's bench.py

M, N, K = 4096, 4096, 4096
a = torch.randn(M, K, device='cuda', dtype=torch.bfloat16)
b = torch.randn(N, K, device='cuda', dtype=torch.bfloat16)   # note: [N, K], transposed
d = torch.zeros(M, N, device='cuda', dtype=torch.bfloat16)   # output, pre-allocated

def fn():
    deep_gemm.bf16_gemm_nt(a, b, d)

# Step 1: identify the kernel name with a one-shot profile
prof = torch.profiler.profile(activities=[torch.profiler.ProfilerActivity.CUDA])
with prof:
    for _ in range(3): fn()
    torch.cuda.synchronize()
print(prof.key_averages().table(sort_by='cuda_time_total', max_name_column_width=120))
# On Blackwell SM100 the kernel is "void deep_gemm::sm100_bf16_gemm_impl<...>" — substring "sm100_bf16_gemm_impl" is unique.

t = bench_kineto(fn, kernel_names='sm100_bf16_gemm_impl', num_tests=30)
tflops = 2 * M * N * K / t / 1e12
print(f"bf16 GEMM {M}x{N}x{K}: {t*1e6:.2f} us, {tflops:.1f} TFLOPS")
```
