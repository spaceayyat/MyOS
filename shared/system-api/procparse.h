#pragma once
// Pure C++17 parsers for /proc/stat and /proc/meminfo. No Qt dependency, so
// they are unit-tested with plain g++ (tests/unit/test_procparse.sh).
#include <sstream>
#include <string>

namespace myos {

struct CpuTimes {
    unsigned long long idle = 0;
    unsigned long long total = 0;
};

struct MemInfo {
    unsigned long long totalKb = 0;
    unsigned long long availableKb = 0;
};

// Parses the aggregate "cpu " line of /proc/stat.
inline bool parseCpuTimes(const std::string &content, CpuTimes *out)
{
    std::istringstream in(content);
    std::string line;
    while (std::getline(in, line)) {
        if (line.compare(0, 4, "cpu ") != 0)
            continue;
        std::istringstream fields(line.substr(4));
        unsigned long long v[8] = {0};
        int n = 0;
        while (n < 8 && (fields >> v[n]))
            ++n;
        if (n < 4)
            return false;
        // user nice system idle iowait irq softirq steal
        unsigned long long total = 0;
        for (int i = 0; i < n; ++i)
            total += v[i];
        out->idle = v[3] + (n > 4 ? v[4] : 0); // idle + iowait
        out->total = total;
        return true;
    }
    return false;
}

// Busy percentage (0..100) between two samples; 0 if no time has passed.
inline double cpuPercent(const CpuTimes &prev, const CpuTimes &cur)
{
    if (cur.total <= prev.total || cur.idle < prev.idle)
        return 0.0;
    const double dTotal = double(cur.total - prev.total);
    const double dIdle = double(cur.idle - prev.idle);
    double pct = (1.0 - dIdle / dTotal) * 100.0;
    if (pct < 0.0) pct = 0.0;
    if (pct > 100.0) pct = 100.0;
    return pct;
}

// Parses MemTotal and MemAvailable (kB) from /proc/meminfo.
inline bool parseMemInfo(const std::string &content, MemInfo *out)
{
    std::istringstream in(content);
    std::string line;
    bool haveTotal = false, haveAvail = false;
    while (std::getline(in, line)) {
        std::istringstream fields(line);
        std::string key;
        unsigned long long value = 0;
        if (!(fields >> key >> value))
            continue;
        if (key == "MemTotal:") { out->totalKb = value; haveTotal = true; }
        else if (key == "MemAvailable:") { out->availableKb = value; haveAvail = true; }
    }
    return haveTotal && haveAvail && out->totalKb > 0;
}

inline double memUsedPercent(const MemInfo &m)
{
    if (m.totalKb == 0 || m.availableKb > m.totalKb)
        return 0.0;
    return double(m.totalKb - m.availableKb) * 100.0 / double(m.totalKb);
}

} // namespace myos
