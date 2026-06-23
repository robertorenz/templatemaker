/* ============================================================================
 *  mc.c - myCompress C engine (OUR OWN implementation).
 *
 *  A from-scratch DEFLATE (RFC 1951) codec with zlib (RFC 1950) and gzip
 *  (RFC 1952) containers - a direct port of our own Clarion CompressClass
 *  algorithm into C, compiled by Clarion's C++ compiler (Clacpp) via
 *  PRAGMA('compile(mc.c)') and called from CompressClass when the C fast-path
 *  is enabled. Not derived from miniz, zlib, StringTheory, or any other
 *  library - this is our code.
 *
 *    mc_compress   : LZ77 hash-chain matcher + fixed Huffman -> raw/zlib/gzip.
 *    mc_decompress : full INFLATE (stored + fixed + dynamic Huffman), auto-
 *                    detects the container.
 *
 *  C has no Clarion 64K-array limit, so the matcher uses the full 32K DEFLATE
 *  window (better ratio than the pure-Clarion 8K) and runs ~4.5x faster (no
 *  per-bit/per-byte method-call overhead).
 *
 *  Note: the work tables are file-scope statics - the C fast-path is single-
 *  threaded. For concurrent compression use the pure-Clarion engine.
 * ========================================================================== */

extern "C" {

typedef unsigned char u8;
typedef unsigned int  u32;

/* ---- checksums ---- */
static u32 crctab[256];
static int crcready = 0;
static void crcinit(void) {
    u32 n, c; int k;
    for (n = 0; n < 256; n++) { c = n; for (k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1); crctab[n] = c; }
    crcready = 1;
}
static u32 mc_crc32(const u8* p, int len) {
    u32 c = 0xFFFFFFFFu; int i;
    if (!crcready) crcinit();
    for (i = 0; i < len; i++) c = (c >> 8) ^ crctab[(c ^ p[i]) & 0xFF];
    return c ^ 0xFFFFFFFFu;
}
static u32 mc_adler32(const u8* p, int len) {
    u32 a = 1, b = 0; int i;
    for (i = 0; i < len; i++) { a += p[i]; if (a >= 65521u) a -= 65521u; b += a; if (b >= 65521u) b -= 65521u; }
    return (b << 16) | a;
}

/* ---- RFC 1951 length / distance base + extra ---- */
static const int lenbase[29] = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258};
static const int lenx[29]    = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0};
static const int dstbase[30] = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577};
static const int dstx[30]    = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13};
static const int clorder[19] = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15};

/* =====================  COMPRESS  ===================== */
static u8* out; static int outpos; static int outcap; static int oerr; static u32 bacc; static int bn;
static void putbyte(int b) { if (outpos >= outcap) { oerr = 1; return; } out[outpos++] = (u8)b; }
static void putbits(u32 v, int n) { bacc |= (v & ((1u << n) - 1)) << bn; bn += n; while (bn >= 8) { putbyte(bacc & 0xFF); bacc >>= 8; bn -= 8; } }
static u32  revbits(u32 v, int n) { u32 r = 0; int i; for (i = 0; i < n; i++) { r = (r << 1) | (v & 1); v >>= 1; } return r; }
static void puthuff(int code, int n) { putbits(revbits((u32)code, n), n); }
static void flushbits(void) { if (bn > 0) { putbyte(bacc & 0xFF); bacc = 0; bn = 0; } }

static int flcode[288], fllen[288], fixdone = 0;
static void fixinit(void) {
    int s;
    if (fixdone) return;
    for (s = 0; s <= 287; s++) {
        if (s <= 143)      { flcode[s] = 0x30 + s;          fllen[s] = 8; }
        else if (s <= 255) { flcode[s] = 0x190 + (s - 144); fllen[s] = 9; }
        else if (s <= 279) { flcode[s] = s - 256;           fllen[s] = 7; }
        else               { flcode[s] = 0xC0 + (s - 280);  fllen[s] = 8; }
    }
    fixdone = 1;
}

#define WSIZE 32768
#define WMASK 32767
#define HSIZE 32768
#define HMASK 32767
#define MINM  3
#define MAXM  258
static int head[HSIZE];
static int hprev[WSIZE];
static int hashof(const u8* s, int i) { return ((s[i] << 10) ^ (s[i + 1] << 5) ^ s[i + 2]) & HMASK; }

static void deflate_body(const u8* src, int srclen, int level) {
    int i, maxchain, cur, chain, bestlen, bestdist, ml, k, p, h, ls, ds;
    maxchain = level <= 1 ? 8 : level <= 4 ? 32 : level <= 6 ? 128 : level <= 8 ? 1024 : 4096;
    for (i = 0; i < HSIZE; i++) head[i] = -1;
    putbits(1, 1); putbits(1, 2);            /* BFINAL=1, BTYPE=01 (fixed Huffman) */
    i = 0;
    while (i < srclen) {
        bestlen = 0; bestdist = 0;
        if (i + MINM <= srclen) {
            h = hashof(src, i); cur = head[h]; chain = maxchain;
            while (cur >= 0 && chain > 0) {
                if (i - cur > WSIZE) break;
                ml = 0; while (ml < MAXM && i + ml < srclen && src[cur + ml] == src[i + ml]) ml++;
                if (ml > bestlen) { bestlen = ml; bestdist = i - cur; if (ml >= MAXM) break; }
                cur = hprev[cur & WMASK]; chain--;
            }
            hprev[i & WMASK] = head[h]; head[h] = i;
        }
        if (bestlen >= MINM) {
            for (ls = 28; ls >= 0; ls--) if (lenbase[ls] <= bestlen) break;
            puthuff(flcode[257 + ls], fllen[257 + ls]);
            if (lenx[ls] > 0) putbits((u32)(bestlen - lenbase[ls]), lenx[ls]);
            for (ds = 29; ds >= 0; ds--) if (dstbase[ds] <= bestdist) break;
            puthuff(ds, 5);
            if (dstx[ds] > 0) putbits((u32)(bestdist - dstbase[ds]), dstx[ds]);
            for (k = 1; k < bestlen; k++) { p = i + k; if (p + MINM <= srclen) { h = hashof(src, p); hprev[p & WMASK] = head[h]; head[h] = p; } }
            i += bestlen;
        } else { puthuff(flcode[src[i]], fllen[src[i]]); i++; }
    }
    puthuff(flcode[256], fllen[256]);        /* end of block */
    flushbits();
}

/* Compress src into dst. format: 0 raw, 1 zlib, 2 gzip. Returns length or -1. */
int mc_compress(u8* dst, int dstcap, const u8* src, int srclen, int level, int format) {
    u32 crc, ad;
    fixinit();
    out = dst; outpos = 0; outcap = dstcap; oerr = 0; bacc = 0; bn = 0;
    if (format == 2) {                       /* gzip header */
        putbyte(0x1F); putbyte(0x8B); putbyte(8); putbyte(0);
        putbyte(0); putbyte(0); putbyte(0); putbyte(0); putbyte(0); putbyte(0xFF);
    } else if (format == 1) {                /* zlib header (0x78 0x01) */
        putbyte(0x78); putbyte(0x01);
    }
    deflate_body(src, srclen, level);
    if (format == 2) {                       /* gzip trailer: CRC32 + ISIZE (LE) */
        crc = mc_crc32(src, srclen);
        putbyte(crc & 0xFF); putbyte((crc >> 8) & 0xFF); putbyte((crc >> 16) & 0xFF); putbyte((crc >> 24) & 0xFF);
        putbyte(srclen & 0xFF); putbyte((srclen >> 8) & 0xFF); putbyte((srclen >> 16) & 0xFF); putbyte((srclen >> 24) & 0xFF);
    } else if (format == 1) {                /* zlib trailer: Adler32 (big-endian) */
        ad = mc_adler32(src, srclen);
        putbyte((ad >> 24) & 0xFF); putbyte((ad >> 16) & 0xFF); putbyte((ad >> 8) & 0xFF); putbyte(ad & 0xFF);
    }
    return oerr ? -1 : outpos;            /* -1 = dst too small (caller grows + retries) */
}

/* =====================  DECOMPRESS  ===================== */
static const u8* inbuf; static int inpos; static int inlen; static u32 bracc; static int brn; static int ierr;
static int byteIn(void) { if (inpos >= inlen) { ierr = 1; return 0; } return inbuf[inpos++]; }
static u32 getbits(int n) { u32 v; while (brn < n) { bracc |= ((u32)byteIn()) << brn; brn += 8; } v = bracc & ((1u << n) - 1); bracc >>= n; brn -= n; return v; }
static void alignbyte(void) { int d = brn & 7; bracc >>= d; brn -= d; }
static int  nextstored(void) { int v; if (brn >= 8) { v = bracc & 0xFF; bracc >>= 8; brn -= 8; return v; } return byteIn(); }

/* canonical Huffman: count[1..15] + symbol[] (puff-style) */
static void buildhuff(const int* lengths, int n, int* count, int* symbol) {
    int i, len, offs[16];
    for (i = 0; i <= 15; i++) count[i] = 0;
    for (i = 0; i < n; i++) if (lengths[i] > 0) count[lengths[i]]++;
    offs[1] = 0;
    for (len = 1; len < 15; len++) offs[len + 1] = offs[len] + count[len];
    for (i = 0; i < n; i++) if (lengths[i] > 0) symbol[offs[lengths[i]]++] = i;
}
static int decodesym(const int* count, const int* symbol) {
    int code = 0, first = 0, index = 0, len, cnt;
    for (len = 1; len <= 15; len++) {
        code |= (int)getbits(1);
        cnt = count[len];
        if (code - first < cnt) return symbol[index + (code - first)];
        index += cnt; first += cnt; first <<= 1; code <<= 1;
    }
    ierr = 1; return -1;
}

static int llcount[16], llsym[288], dcount[16], dsym[30], clcount[16], clsym[19];
static int codelen[320], dlen2[32];

static int inflate_block(u8* dst, int dstcap, int* outlen) {
    int s, ds, length, dist, srcp, k, op = *outlen;
    for (;;) {
        s = decodesym(llcount, llsym);
        if (s < 0) return 0;
        if (s < 256) { if (op >= dstcap) { ierr = 1; return 0; } dst[op++] = (u8)s; }
        else if (s == 256) { *outlen = op; return 1; }
        else {
            s -= 257; if (s > 28) { ierr = 1; return 0; }
            length = lenbase[s] + (int)getbits(lenx[s]);
            ds = decodesym(dcount, dsym); if (ds < 0) return 0;
            if (ds > 29) { ierr = 1; return 0; }
            dist = dstbase[ds] + (int)getbits(dstx[ds]);
            if (dist > op) { ierr = 1; return 0; }
            if (op + length > dstcap) { ierr = 1; return 0; }   /* dst too small */
            srcp = op - dist;
            for (k = 0; k < length; k++) { dst[op] = dst[srcp + k]; op++; }
        }
        if (ierr) return 0;
    }
}

static void build_fixed(void) {
    int s;
    for (s = 0; s <= 287; s++) codelen[s] = (s <= 143) ? 8 : (s <= 255) ? 9 : (s <= 279) ? 7 : 8;
    buildhuff(codelen, 288, llcount, llsym);
    for (s = 0; s < 30; s++) codelen[s] = 5;
    buildhuff(codelen, 30, dcount, dsym);
}

static int read_dynamic(void) {
    int hlit, hdist, hclen, i, j, s, rep, prev;
    hlit = (int)getbits(5) + 257; hdist = (int)getbits(5) + 1; hclen = (int)getbits(4) + 4;
    for (i = 0; i < 19; i++) codelen[i] = 0;
    for (i = 0; i < hclen; i++) codelen[clorder[i]] = (int)getbits(3);
    buildhuff(codelen, 19, clcount, clsym);
    i = 0;
    while (i < hlit + hdist) {
        s = decodesym(clcount, clsym); if (s < 0) return 0;
        if (s < 16) { codelen[i++] = s; }
        else if (s == 16) { rep = (int)getbits(2) + 3; if (i < 1) { ierr = 1; return 0; } prev = codelen[i - 1]; for (j = 0; j < rep; j++) codelen[i++] = prev; }
        else if (s == 17) { rep = (int)getbits(3) + 3;  for (j = 0; j < rep; j++) codelen[i++] = 0; }
        else              { rep = (int)getbits(7) + 11; for (j = 0; j < rep; j++) codelen[i++] = 0; }
        if (ierr) return 0;
    }
    buildhuff(codelen, hlit, llcount, llsym);
    for (j = 0; j < hdist; j++) dlen2[j] = codelen[hlit + j];
    buildhuff(dlen2, hdist, dcount, dsym);
    return 1;
}

/* Decompress src (auto-detects gzip/zlib/raw) into dst. Returns length or -1. */
int mc_decompress(u8* dst, int dstcap, const u8* src, int srclen) {
    int bfinal, btype, lenv, nlen, i, outlen = 0, flg, xl;
    inbuf = src; inlen = srclen; inpos = 0; bracc = 0; brn = 0; ierr = 0;
    if (srclen >= 2 && src[0] == 0x1F && src[1] == 0x8B) {       /* gzip */
        flg = src[3]; inpos = 10;
        if (flg & 4) { xl = byteIn(); xl |= byteIn() << 8; inpos += xl; }
        if (flg & 8)  { while (byteIn() != 0 && !ierr) {} }
        if (flg & 16) { while (byteIn() != 0 && !ierr) {} }
        if (flg & 2)  inpos += 2;
        bracc = 0; brn = 0;
    } else if (srclen >= 2 && (src[0] & 0x0F) == 8 && ((src[0] * 256 + src[1]) % 31) == 0) {
        inpos = 2; bracc = 0; brn = 0;                          /* zlib */
    } else {
        inpos = 0;                                              /* raw deflate */
    }
    do {
        bfinal = (int)getbits(1); btype = (int)getbits(2);
        if (ierr) return -1;
        if (btype == 0) {
            alignbyte();
            lenv = nextstored(); lenv |= nextstored() << 8;
            nlen = nextstored(); nlen |= nextstored() << 8;
            if (lenv != ((~nlen) & 0xFFFF)) return -1;
            if (outlen + lenv > dstcap) return -1;              /* dst too small */
            for (i = 0; i < lenv; i++) dst[outlen++] = (u8)nextstored();
        } else if (btype == 1) {
            build_fixed(); if (!inflate_block(dst, dstcap, &outlen)) return -1;
        } else if (btype == 2) {
            if (!read_dynamic()) return -1;
            if (!inflate_block(dst, dstcap, &outlen)) return -1;
        } else return -1;
        if (ierr) return -1;
    } while (!bfinal);
    return outlen;
}

} /* extern "C" */
