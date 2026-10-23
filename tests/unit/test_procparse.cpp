#include "procparse.h"
#include <cmath>
#include <cstdio>
static int failed = 0;
#define CHECK(c) do { if (!(c)) { std::printf("  FAIL  %s (line %d)\n", #c, __LINE__); ++failed; } else std::printf("  PASS  %s\n", #c); } while (0)
static bool near(double a, double b) { return std::fabs(a - b) < 0.01; }
int main()
{
    using namespace myos;
    CpuTimes a, b;
    CHECK(parseCpuTimes("cpu0 1 1 1 1\ncpu  100 0 50 800 50 0 0 0 0 0\n", &a));
    CHECK(a.total == 1000 && a.idle == 850);
    CHECK(parseCpuTimes("cpu  200 0 100 850 50\n", &b));
    CHECK(near(cpuPercent(a, b), 75.0)); // 150 busy / 200 total
    CHECK(near(cpuPercent(a, a), 0.0));  // no time passed
    CpuTimes bad; CHECK(!parseCpuTimes("intr 1 2 3\n", &bad));
    CHECK(!parseCpuTimes("cpu  1 2\n", &bad));
    MemInfo m;
    CHECK(parseMemInfo("MemTotal:       8000000 kB\nMemFree: 1 kB\nMemAvailable:   2000000 kB\n", &m));
    CHECK(near(memUsedPercent(m), 75.0));
    MemInfo n; CHECK(!parseMemInfo("MemTotal: 5 kB\n", &n));
    CHECK(!parseMemInfo("", &n));
    std::printf("\n[myos] procparse: %s\n", failed ? "FAILED" : "all passed");
    return failed ? 1 : 0;
}
