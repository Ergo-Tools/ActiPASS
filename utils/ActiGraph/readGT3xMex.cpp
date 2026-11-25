/*
 * readGT3xMex.cpp - MEX parser for the activity samples in ActiGraph .gt3x files
 *
 * Parses the unzipped 'log.bin' (GT3X+ / wGT3X-BT / GT9X / CentrePoint format)
 * or the older NHANES-era 'activity.bin' and returns a continuous, gap-filled
 * [N x 3] matrix of accelerations in g. Called by readActGT3x.m, which unzips
 * the .gt3x container and parses info.txt.
 *
 * Usage (from MATLAB):
 *   [acc, nFilled] = readGT3xMex(binFile, format, startSec, SF, scale, nRows, fillMode)
 *     binFile  : path to log.bin or activity.bin (char)
 *     format   : 0 = log.bin, 1 = NHANES activity.bin
 *     startSec : recording start in seconds since 1970-01-01 (local clock, from
 *                info.txt 'Start Date'); row 1 of acc is at this time
 *     SF       : sample frequency (Hz, integer)
 *     scale    : acceleration scale (counts per g, from info.txt)
 *     nRows    : minimum number of output rows (e.g. from 'Last Sample Time');
 *                0 = end at the last activity packet
 *     fillMode : 0 = zeros, 1 = repeat last sample (ActiLife behaviour), for
 *                idle-sleep-mode gaps and missing samples
 *   acc      : [N x 3] double, columns in the ActiLife order Y, X, Z (the order
 *              readActGT3xcsv returns them in), rounded to 3 decimals
 *   nFilled  : number of rows that were filled (no sample in the file)
 *
 * The record parsing, 12-bit sample unpacking, scaling and rounding are ported
 * from the R package read.gt3x (src/parseGT3X.cpp, version 1.4.0),
 *   https://github.com/THLfi/read.gt3x
 *   Copyright (c) Tuomo Nieminen, John Muschelli and contributors,
 * which is licensed under the European Union Public Licence (EUPL). This file,
 * as a derivative work, is distributed under the EUPL v1.2:
 *   https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12
 * Format documentation: https://github.com/actigraph/GT3X-File-Format and
 * https://github.com/actigraph/NHANES-GT3X-File-Format
 *
 * Differences from read.gt3x: samples are placed on a time grid from their
 * packet time stamp (so partial or duplicated packets cannot shift later data),
 * and gaps can be filled with the last sample as ActiLife's CSV export does.
 *
 * Build (in MATLAB, from this folder):
 *   mex -O readGT3xMex.cpp
 *
 * Adapted for Actipass by Pasan Hettiarachchi, 2026.
 */

#include "mex.h"
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <vector>
#include <string>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace {

const uint8_t RECORD_SEPARATOR   = 0x1E;
const uint8_t RECORDTYPE_ACTIVITY  = 0x00; // 12-bit packed samples, YXZ order
const uint8_t RECORDTYPE_ACTIVITY2 = 0x1A; // int16 little-endian samples, XYZ order

bool readWholeFile(const char *utf8Path, std::vector<uint8_t> &buf)
{
    FILE *fp = NULL;
#ifdef _WIN32
    int n = MultiByteToWideChar(CP_UTF8, 0, utf8Path, -1, NULL, 0);
    std::vector<wchar_t> wpath(n > 0 ? n : 1);
    MultiByteToWideChar(CP_UTF8, 0, utf8Path, -1, wpath.data(), n);
    fp = _wfopen(wpath.data(), L"rb");
#else
    fp = fopen(utf8Path, "rb");
#endif
    if (!fp) return false;
#ifdef _WIN32
    _fseeki64(fp, 0, SEEK_END);
    long long len = _ftelli64(fp);
    _fseeki64(fp, 0, SEEK_SET);
#else
    fseeko(fp, 0, SEEK_END);
    long long len = (long long)ftello(fp);
    fseeko(fp, 0, SEEK_SET);
#endif
    if (len < 0) { fclose(fp); return false; }
    buf.resize((size_t)len);
    size_t got = len > 0 ? fread(buf.data(), 1, (size_t)len, fp) : 0;
    fclose(fp);
    return got == (size_t)len;
}

inline uint16_t rdU16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
inline uint32_t rdU32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

// Unpack nSamples x 3 12-bit two's-complement values (read.gt3x ParseActivity).
// out receives counts in file order (Y, X, Z). Returns samples fully decoded.
long long unpack12(const uint8_t *p, size_t nBytes, long long nSamples, int16_t *out)
{
    size_t pos = 0;
    bool odd = false;
    int current = 0;
    for (long long i = 0; i < nSamples; ++i) {
        for (int j = 0; j < 3; ++j) {
            uint16_t shifter;
            if (!odd) {
                if (pos + 2 > nBytes) return i;
                current = p[pos++];
                shifter = (uint16_t)((current & 0xFF) << 4);
                current = p[pos++];
                shifter |= (uint16_t)((current & 0xF0) >> 4);
            } else {
                shifter = (uint16_t)((current & 0x0F) << 8);
                if (pos + 1 > nBytes) return i;
                current = p[pos++];
                shifter |= (uint16_t)(current & 0xFF);
            }
            if (shifter & 0x0800) shifter |= 0xF000; // sign extension
            out[i * 3 + j] = (int16_t)shifter;
            odd = !odd;
        }
    }
    return nSamples;
}

struct Packet {
    size_t   offset;   // payload offset in buffer
    uint16_t size;     // payload bytes
    uint8_t  type;
    long long row0;    // output row of the first sample
    int      nSamples;
};

} // namespace

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs != 7)
        mexErrMsgIdAndTxt("readGT3xMex:nrhs",
            "Usage: [acc,nFilled] = readGT3xMex(binFile,format,startSec,SF,scale,nRows,fillMode)");
    if (!mxIsChar(prhs[0]))
        mexErrMsgIdAndTxt("readGT3xMex:arg", "binFile must be a char array.");

    char *path = mxArrayToUTF8String(prhs[0]);
    const int    format   = (int)mxGetScalar(prhs[1]);
    const double startSec = mxGetScalar(prhs[2]);
    const int    SF       = (int)mxGetScalar(prhs[3]);
    const double scale    = mxGetScalar(prhs[4]);
    const double nRowsMin = mxGetScalar(prhs[5]);
    const int    fillMode = (int)mxGetScalar(prhs[6]);

    if (SF <= 0)     mexErrMsgIdAndTxt("readGT3xMex:arg", "SF must be positive.");
    if (scale <= 0)  mexErrMsgIdAndTxt("readGT3xMex:arg", "scale must be positive.");

    std::vector<uint8_t> buf;
    bool ok = readWholeFile(path, buf);
    std::string pathStr(path ? path : "");
    mxFree(path);
    if (!ok)
        mexErrMsgIdAndTxt("readGT3xMex:open", "Cannot read file: %s", pathStr.c_str());

    std::vector<int16_t> counts;   // decoded counts, 3 per sample, file order
    std::vector<long long> rowOf;  // output row for each decoded sample
    std::vector<long long> zeroRows; // first rows of empty activity packets
    long long nRows = 0;

    if (format == 1) {
        // NHANES activity.bin: one continuous stream of 12-bit YXZ samples.
        long long n = (long long)((double)buf.size() * 8.0 / 36.0);
        counts.resize((size_t)n * 3);
        n = unpack12(buf.data(), buf.size(), n, counts.data());
        counts.resize((size_t)n * 3);
        rowOf.resize((size_t)n);
        for (long long i = 0; i < n; ++i) rowOf[(size_t)i] = i;
        nRows = n;
    } else {
        // log.bin: records of [0x1E][type][uint32 time][uint16 size][payload][checksum]
        std::vector<Packet> packets;
        const size_t len = buf.size();
        size_t p = 0;
        long long totalSamples = 0;
        long long nBefore = 0;
        while (p < len) {
            if (buf[p] != RECORD_SEPARATOR) { ++p; continue; }
            if (p + 8 > len) break;
            const uint8_t  type = buf[p + 1];
            const uint32_t ts   = rdU32(&buf[p + 2]);
            const uint16_t size = rdU16(&buf[p + 6]);
            const size_t payload = p + 8;
            if (payload + size > len) break; // truncated last record
            if (type == RECORDTYPE_ACTIVITY || type == RECORDTYPE_ACTIVITY2) {
                int ns = (type == RECORDTYPE_ACTIVITY) ? (size * 2) / 9 : (size / 2) / 3;
                if (ns > SF) ns = SF;
                long long row0 = (long long)llround(((double)ts - startSec) * SF);
                if (row0 < 0) {
                    ++nBefore;
                } else if (ns == 0) {
                    // empty packet: a second of zeros (as read.gt3x and ActiLife)
                    zeroRows.push_back(row0);
                    if (row0 + SF > nRows) nRows = row0 + SF;
                } else {
                    Packet pk = { payload, size, type, row0, ns };
                    packets.push_back(pk);
                    totalSamples += ns;
                    if (row0 + ns > nRows) nRows = row0 + ns;
                }
            }
            p = payload + size + 1; // skip payload and checksum
        }
        if (nBefore > 0)
            mexWarnMsgIdAndTxt("readGT3xMex:early",
                "%lld activity packets before the start time were skipped.", nBefore);

        counts.resize((size_t)totalSamples * 3);
        rowOf.resize((size_t)totalSamples);
        long long k = 0;
        for (size_t i = 0; i < packets.size(); ++i) {
            const Packet &pk = packets[i];
            const uint8_t *src = &buf[pk.offset];
            int16_t *dst = &counts[(size_t)k * 3];
            long long got;
            if (pk.type == RECORDTYPE_ACTIVITY) {
                got = unpack12(src, pk.size, pk.nSamples, dst); // already Y, X, Z
            } else {
                for (int s = 0; s < pk.nSamples; ++s) {     // X, Y, Z -> Y, X, Z
                    const uint8_t *q = src + s * 6;
                    dst[s * 3 + 0] = (int16_t)rdU16(q + 2);
                    dst[s * 3 + 1] = (int16_t)rdU16(q + 0);
                    dst[s * 3 + 2] = (int16_t)rdU16(q + 4);
                }
                got = pk.nSamples;
            }
            for (long long s = 0; s < got; ++s) rowOf[(size_t)(k + s)] = pk.row0 + s;
            k += got;
        }
        counts.resize((size_t)k * 3);
        rowOf.resize((size_t)k);
    }

    if (nRowsMin > (double)nRows) nRows = (long long)nRowsMin;

    // Scatter scaled samples onto the time grid; NaN marks rows without data.
    plhs[0] = mxCreateDoubleMatrix((mwSize)nRows, 3, mxREAL);
    double *acc = mxGetPr(plhs[0]);
    const double nanv = mxGetNaN();
    for (long long r = 0; r < 3 * nRows; ++r) acc[r] = nanv;

    const double mult = 1000.0; // 3 decimals, as read.gt3x and ActiLife CSV
    const size_t nDec = rowOf.size();
    for (size_t i = 0; i < nDec; ++i) {
        const long long r = rowOf[i];
        if (r < 0 || r >= nRows) continue;
        for (int j = 0; j < 3; ++j)
            acc[r + j * nRows] = round(((double)counts[i * 3 + j] / scale) * mult) / mult;
    }
    std::vector<int16_t>().swap(counts);
    std::vector<long long>().swap(rowOf);
    std::vector<uint8_t>().swap(buf);

    // Empty packets become a second of zeros, so the gap after them also
    // fills with zeros in fillMode 1 (matches the ActiLife CSV export).
    long long nFilled = 0;
    for (size_t i = 0; i < zeroRows.size(); ++i) {
        for (long long r = zeroRows[i]; r < zeroRows[i] + SF && r < nRows; ++r) {
            if (mxIsNaN(acc[r])) {
                ++nFilled;
                for (int j = 0; j < 3; ++j) acc[r + j * nRows] = 0.0;
            }
        }
    }

    // Fill gaps (idle sleep mode, missing packets, partial seconds).
    double last[3] = {0.0, 0.0, 0.0};
    for (long long r = 0; r < nRows; ++r) {
        if (mxIsNaN(acc[r])) {
            ++nFilled;
            for (int j = 0; j < 3; ++j) acc[r + j * nRows] = fillMode == 1 ? last[j] : 0.0;
        } else if (fillMode == 1) {
            for (int j = 0; j < 3; ++j) last[j] = acc[r + j * nRows];
        }
    }

    if (nlhs > 1) plhs[1] = mxCreateDoubleScalar((double)nFilled);
}
