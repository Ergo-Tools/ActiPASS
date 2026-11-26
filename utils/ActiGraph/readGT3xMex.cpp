/*
 * readGT3xMex.cpp - MEX parser for the activity samples in ActiGraph .gt3x files
 *
 * Reads the .gt3x (zip) archive in memory with miniz (no temporary files),
 * parses 'log.bin' (GT3X+ / wGT3X-BT / GT9X / CentrePoint format) or the older
 * NHANES-era 'activity.bin' and returns a continuous, gap-filled matrix of time
 * and accelerations in g. Called by readActGT3x.m, which parses info.txt.
 *
 * Usage (from MATLAB):
 *   [infoTxt, names] = readGT3xMex(gt3xFile)
 *     infoTxt  : text of info.txt (char)
 *     names    : entry names in the archive (cell)
 *   [data, nFilled] = readGT3xMex(gt3xFile, format, startSec, SF, scale, nRows, fillMode)
 *     gt3xFile : path to the .gt3x file (char)
 *     format   : 0 = log.bin, 1 = NHANES activity.bin
 *     startSec : recording start in seconds since 1970-01-01 (local clock, from
 *                info.txt 'Start Date'); row 1 of acc is at this time
 *     SF       : sample frequency (Hz, integer)
 *     scale    : acceleration scale (counts per g, from info.txt)
 *     nRows    : minimum number of output rows (e.g. from 'Last Sample Time');
 *                0 = end at the last activity packet
 *     fillMode : 0 = zeros, 1 = repeat last sample (ActiLife behaviour), for
 *                idle-sleep-mode gaps and missing samples
 *   data     : [N x 4] double: time as a MATLAB datenum (device local time,
 *              startSec + (row-1)/SF), then the axes in the ActiLife order
 *              Y, X, Z (the order readActGT3xcsv returns them in), in g
 *              rounded to 3 decimals
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
 * Zip reading uses miniz 3.0.2 (miniz.c/miniz.h, MIT licence, see
 * LICENSE-miniz.txt): https://github.com/richgel999/miniz
 *
 * Build (in MATLAB, from this folder):
 *   mex -O readGT3xMex.cpp miniz.c
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
#include <memory>
#include <new>
#include "miniz.h"

namespace {

const uint8_t RECORD_SEPARATOR   = 0x1E;
const uint8_t RECORDTYPE_ACTIVITY  = 0x00; // 12-bit packed samples, YXZ order
const uint8_t RECORDTYPE_ACTIVITY2 = 0x1A; // int16 little-endian samples, XYZ order

// Open the .gt3x (zip) archive; miniz converts the UTF-8 path for Windows.
bool openZip(mz_zip_archive &zip, const std::string &path, std::string &err)
{
    std::memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_file(&zip, path.c_str(), 0)) {
        err = "Cannot open '" + path + "' as a .gt3x (zip) file: " +
              mz_zip_get_error_string(mz_zip_get_last_error(&zip));
        return false;
    }
    return true;
}

// Inflate one archive entry (matched on its name without folder, ignoring
// case) straight into a single heap buffer: no temporary files, no extra copy.
bool inflateEntry(mz_zip_archive &zip, const char *name,
                  std::unique_ptr<uint8_t[]> &buf, size_t &len, std::string &err)
{
    int idx = mz_zip_reader_locate_file(&zip, name, NULL, MZ_ZIP_FLAG_IGNORE_PATH);
    mz_zip_archive_file_stat st;
    if (idx < 0 || !mz_zip_reader_file_stat(&zip, (mz_uint)idx, &st)) {
        err = std::string("no ") + name + " found in the .gt3x file";
        return false;
    }
    if (st.m_uncomp_size > (mz_uint64)SIZE_MAX - 1) {
        err = std::string(name) + " is too large";
        return false;
    }
    len = (size_t)st.m_uncomp_size;
    buf.reset(new (std::nothrow) uint8_t[len > 0 ? len : 1]);
    if (!buf) {
        err = std::string("out of memory inflating ") + name;
        return false;
    }
    if (len > 0 && !mz_zip_reader_extract_to_mem(&zip, (mz_uint)idx, buf.get(), len, 0)) {
        err = std::string("cannot inflate ") + name + " (corrupt .gt3x file?): " +
              mz_zip_get_error_string(mz_zip_get_last_error(&zip));
        buf.reset();
        return false;
    }
    return true;
}

std::string argString(const mxArray *a)
{
    char *s = mxArrayToUTF8String(a);
    std::string out(s ? s : "");
    mxFree(s);
    return out;
}

// [infoTxt, names] = readGT3xMex(gt3xFile): info.txt text and entry names.
void readInfo(int nlhs, mxArray *plhs[], const std::string &path)
{
    mz_zip_archive zip;
    std::string err;
    std::unique_ptr<uint8_t[]> buf;
    size_t len = 0;
    bool ok = openZip(zip, path, err);
    if (ok) ok = inflateEntry(zip, "info.txt", buf, len, err);
    std::vector<std::string> names;
    if (ok) {
        const mz_uint n = mz_zip_reader_get_num_files(&zip);
        for (mz_uint i = 0; i < n; ++i) {
            char nm[1024];
            if (mz_zip_reader_get_filename(&zip, i, nm, sizeof(nm)) > 0) names.push_back(nm);
        }
    }
    mz_zip_reader_end(&zip);
    if (!ok) mexErrMsgIdAndTxt("readGT3xMex:zip", "%s", err.c_str());

    size_t off = (len >= 3 && buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF) ? 3 : 0; // UTF-8 BOM
    std::string txt(reinterpret_cast<const char *>(buf.get()) + off, len - off);
    plhs[0] = mxCreateString(txt.c_str());
    if (nlhs > 1) {
        plhs[1] = mxCreateCellMatrix((mwSize)names.size(), 1);
        for (size_t i = 0; i < names.size(); ++i)
            mxSetCell(plhs[1], (mwIndex)i, mxCreateString(names[i].c_str()));
    }
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
    if ((nrhs != 1 && nrhs != 7) || !mxIsChar(prhs[0]))
        mexErrMsgIdAndTxt("readGT3xMex:nrhs",
            "Usage: [infoTxt,names] = readGT3xMex(gt3xFile) or "
            "[data,nFilled] = readGT3xMex(gt3xFile,format,startSec,SF,scale,nRows,fillMode)");

    const std::string path = argString(prhs[0]);
    if (nrhs == 1) {
        readInfo(nlhs, plhs, path);
        return;
    }

    const int    format   = (int)mxGetScalar(prhs[1]);
    const double startSec = mxGetScalar(prhs[2]);
    const double SFd      = mxGetScalar(prhs[3]);
    const int    SF       = (int)SFd;
    const double scale    = mxGetScalar(prhs[4]);
    const double nRowsMin = mxGetScalar(prhs[5]);
    const int    fillMode = (int)mxGetScalar(prhs[6]);

    if (SF <= 0)     mexErrMsgIdAndTxt("readGT3xMex:arg", "SF must be positive.");
    if (scale <= 0)  mexErrMsgIdAndTxt("readGT3xMex:arg", "scale must be positive.");

    // Inflate log.bin / activity.bin from the archive into memory.
    std::unique_ptr<uint8_t[]> bufPtr;
    size_t len = 0;
    {
        mz_zip_archive zip;
        std::string err;
        bool ok = openZip(zip, path, err);
        if (ok) ok = inflateEntry(zip, format == 1 ? "activity.bin" : "log.bin", bufPtr, len, err);
        mz_zip_reader_end(&zip);
        if (!ok) mexErrMsgIdAndTxt("readGT3xMex:zip", "%s", err.c_str());
    }
    const uint8_t *buf = bufPtr.get();

    std::vector<int16_t> counts;     // NHANES: decoded counts, 3 per sample, file order
    std::vector<Packet> packets;     // log.bin: activity packets with data
    std::vector<long long> zeroRows; // first rows of empty activity packets
    long long nRows = 0;

    if (format == 1) {
        // NHANES activity.bin: one continuous stream of 12-bit YXZ samples.
        long long n = (long long)((double)len * 8.0 / 36.0);
        counts.resize((size_t)n * 3);
        n = unpack12(buf, len, n, counts.data());
        counts.resize((size_t)n * 3);
        nRows = n;
    } else {
        // log.bin: records of [0x1E][type][uint32 time][uint16 size][payload][checksum]
        size_t p = 0;
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
                    if (row0 + ns > nRows) nRows = row0 + ns;
                }
            }
            p = payload + size + 1; // skip payload and checksum
        }
        if (nBefore > 0)
            mexWarnMsgIdAndTxt("readGT3xMex:early",
                "%lld activity packets before the start time were skipped.", nBefore);
    }

    if (nRowsMin > (double)nRows) nRows = (long long)nRowsMin;

    // Output [nRows x 4]: time (datenum, device local time) and Y, X, Z in g.
    // The time column repeats readActGT3x's former MATLAB expression
    // startTime + (0:nRows-1)'/SF/86400 operation by operation, so the values
    // are bit-identical, without a second full-size matrix in MATLAB.
    plhs[0] = mxCreateDoubleMatrix((mwSize)nRows, 4, mxREAL);
    double *tcol = mxGetPr(plhs[0]);
    const double startTime = 719529.0 + startSec / 86400.0; // datenum(1970,1,1)
    for (long long r = 0; r < nRows; ++r) tcol[r] = startTime + ((double)r / SFd) / 86400.0;

    // Scatter scaled samples onto the time grid; NaN marks rows without data.
    double *acc = tcol + nRows;
    const double nanv = mxGetNaN();
    for (long long r = 0; r < 3 * nRows; ++r) acc[r] = nanv;

    const double mult = 1000.0; // 3 decimals, as read.gt3x and ActiLife CSV
    if (format == 1) {
        const long long n = (long long)(counts.size() / 3);
        for (long long r = 0; r < n && r < nRows; ++r)
            for (int j = 0; j < 3; ++j)
                acc[r + j * nRows] = round(((double)counts[r * 3 + j] / scale) * mult) / mult;
        std::vector<int16_t>().swap(counts);
    } else {
        // decode each packet straight into the output (later packets win)
        std::vector<int16_t> tmp((size_t)SF * 3);
        for (size_t i = 0; i < packets.size(); ++i) {
            const Packet &pk = packets[i];
            const uint8_t *src = buf + pk.offset;
            int16_t *dst = tmp.data();
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
            for (long long s = 0; s < got; ++s) {
                const long long r = pk.row0 + s;
                if (r < 0 || r >= nRows) continue;
                for (int j = 0; j < 3; ++j)
                    acc[r + j * nRows] = round(((double)dst[s * 3 + j] / scale) * mult) / mult;
            }
        }
    }
    std::vector<Packet>().swap(packets);
    bufPtr.reset();

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
