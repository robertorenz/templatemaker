// ============================================================================
//  PdfSignCore - the golden-fixture oracle for the myPdfSign Clarion template.
//
//  myPdfSign reads a digitally-signed PDF in pure Clarion (PdfSignClass) and
//  reports WHO signed it: the signer certificate's Subject (CN / O / OU /
//  e-mail), the issuing CA, the signing time, the human-readable /Name /Reason
//  /Location fields, the /SubFilter, and whether the signature's /ByteRange
//  covers the whole file (an integrity hint - if it does not, bytes were
//  appended after signing).
//
//  Clarion cannot be run from CI, so - exactly like CompressCore / QrCodeCore -
//  this small .NET tool is the independent reference. .NET owns the trusted
//  building blocks (X509 cert creation, PKCS#7 / CMS via SignedCms), so the
//  tool both (1) MANUFACTURES real signed PDFs as golden fixtures, and
//  (2) re-parses them with SignedCms to publish the ground-truth identity the
//  Clarion side must reproduce byte-for-byte.
//
//  Commands:
//     dotnet run -- vectors <dir>   write caseN.pdf + caseN.expected.txt + manifest
//     dotnet run -- parse  <pdf>    print the identity SignedCms extracts (cross-check)
//     dotnet run -- verify <dir>    compare caseN.actual.txt (from Clarion) to expected
//     dotnet run -- selfcheck       manufacture every case in-memory and re-parse it
// ============================================================================
using System.Formats.Asn1;
using System.Security.Cryptography;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography.X509Certificates;
using System.Text;

internal static class Program
{
    // ---- the cases: each becomes one signed PDF fixture ---------------------
    record Case(
        string Id, string SubjectCN, string SubjectO, string SubjectOU, string SubjectEmail,
        string IssuerCN, string Name, string Reason, string Location, string SignTimeUtc,
        bool TamperAppend);   // if true, append bytes after signing so ByteRange no longer covers the file

    static readonly Case[] Cases =
    {
        new("case1", "Alice Anderson", "Redding Assessments", "Engineering", "alice@reddinassessments.com",
            "Redding Root CA", "Alice Anderson", "I approve this document", "New York, NY",
            "2024-01-15T12:00:00Z", false),
        new("case2", "Bob Builder", "Acme Construction Ltd", "Operations", "bob@acme.example",
            "Acme Internal CA", "Bob Builder", "Reviewed and accepted", "London, UK",
            "2023-11-02T09:30:00Z", false),
        new("case3", "Carol O'Neil", "Health Trust", "Records", "carol.oneil@health.example",
            "Health Trust CA", "Carol O'Neil", "Certified copy", "Dublin, IE",
            "2025-06-01T16:45:00Z", true),   // tampered: bytes appended after signing
    };

    static int Main(string[] args)
    {
        if (args.Length == 0) { Usage(); return 2; }
        switch (args[0])
        {
            case "vectors":   return Vectors(args.Length > 1 ? args[1] : "vectors");
            case "parse":     return ParseCmd(args[1]);
            case "verify":    return Verify(args.Length > 1 ? args[1] : "vectors");
            case "selfcheck": return SelfCheck();
            default: Usage(); return 2;
        }
    }

    static void Usage() => Console.Error.WriteLine(
        "usage: PdfSignCore vectors <dir> | parse <pdf> | verify <dir> | selfcheck");

    // ========================================================================
    //  Certificate manufacture: a root CA, then a leaf signed by that CA so the
    //  fixture has a genuine issuer DN distinct from the subject DN.
    // ========================================================================
    static X509Certificate2 MakeCa(string cn)
    {
        using var rsa = RSA.Create(2048);
        var req = new CertificateRequest($"CN={cn}", rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        req.CertificateExtensions.Add(new X509BasicConstraintsExtension(true, false, 0, true));
        req.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.KeyCertSign | X509KeyUsageFlags.CrlSign, true));
        var notBefore = new DateTimeOffset(2020, 1, 1, 0, 0, 0, TimeSpan.Zero);
        var notAfter  = new DateTimeOffset(2035, 1, 1, 0, 0, 0, TimeSpan.Zero);
        return req.CreateSelfSigned(notBefore, notAfter);
    }

    static X509Certificate2 MakeLeaf(Case c, X509Certificate2 ca)
    {
        using var rsa = RSA.Create(2048);
        // Build a multi-RDN subject. emailAddress (1.2.840.113549.1.9.1) is added as an
        // explicit RDN so a pure-DER reader can find it without parsing SAN extensions.
        var sb = new StringBuilder();
        sb.Append($"CN={c.SubjectCN}");
        if (c.SubjectOU.Length > 0) sb.Append($", OU={c.SubjectOU}");
        if (c.SubjectO.Length  > 0) sb.Append($", O={c.SubjectO}");
        if (c.SubjectEmail.Length > 0) sb.Append($", E={c.SubjectEmail}");
        var dn = new X500DistinguishedName(sb.ToString());

        var req = new CertificateRequest(dn, rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        req.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, false));
        req.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.NonRepudiation, true));

        var serial = new byte[8];
        for (int i = 0; i < serial.Length; i++) serial[i] = (byte)(c.Id.GetHashCode() >> (i * 4));
        serial[0] |= 0x40;  // keep it positive / non-trivial
        var notBefore = new DateTimeOffset(2022, 1, 1, 0, 0, 0, TimeSpan.Zero);
        var notAfter  = new DateTimeOffset(2030, 1, 1, 0, 0, 0, TimeSpan.Zero);
        var leaf = req.Create(ca, notBefore, notAfter, serial);
        return leaf.CopyWithPrivateKey(rsa);
    }

    // ========================================================================
    //  PDF manufacture: a minimal one-page PDF with an AcroForm signature field
    //  and a detached PKCS#7 signature whose ByteRange brackets the /Contents.
    // ========================================================================
    const int ContentsHexLen = 16384;   // reserved hex chars for the DER signature (plenty for RSA-2048 PKCS#7)
    const int ByteRangeFieldLen = 48;   // reserved chars inside the ByteRange brackets after the leading "0 "

    static byte[] BuildSignedPdf(Case c, X509Certificate2 leaf)
    {
        // 1) Assemble the PDF with placeholders for /ByteRange and /Contents.
        var brPlaceholder = "0 " + new string(' ', ByteRangeFieldLen);   // patched once offsets are known
        var contentsZeros = new string('0', ContentsHexLen);
        string m = "D:" + DateTime.Parse(c.SignTimeUtc).ToUniversalTime().ToString("yyyyMMddHHmmss") + "Z";

        var objs = new List<string>
        {
            "<</Type/Catalog/Pages 2 0 R/AcroForm<</Fields[4 0 R]/SigFlags 3>>>>",
            "<</Type/Pages/Kids[3 0 R]/Count 1>>",
            "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Annots[4 0 R]/Contents 6 0 R>>",
            "<</Type/Annot/Subtype/Widget/FT/Sig/T(Signature1)/Rect[36 700 320 740]/V 5 0 R/P 3 0 R>>",
            "<</Type/Sig/Filter/Adobe.PPKLite/SubFilter/adbe.pkcs7.detached" +
                $"/Name({Esc(c.Name)})/Reason({Esc(c.Reason)})/Location({Esc(c.Location)})/M({m})" +
                $"/ByteRange [{brPlaceholder}]/Contents <{contentsZeros}>>>",
            "<</Length 44>>\nstream\nBT /F1 24 Tf 72 720 Td (Signed PDF) Tj ET\nendstream",
        };

        // 2) Serialise body, recording each object's byte offset for the xref table.
        var sb = new StringBuilder();
        sb.Append("%PDF-1.7\n%âãÏÓ\n");
        var offsets = new int[objs.Count + 1];
        var head = Latin1(sb.ToString());
        var body = new MemoryStream();
        body.Write(head);
        for (int i = 0; i < objs.Count; i++)
        {
            offsets[i + 1] = (int)body.Length;
            body.Write(Latin1($"{i + 1} 0 obj\n{objs[i]}\nendobj\n"));
        }
        int xrefPos = (int)body.Length;
        var xref = new StringBuilder();
        xref.Append("xref\n0 ").Append(objs.Count + 1).Append('\n');
        xref.Append("0000000000 65535 f \n");
        for (int i = 1; i <= objs.Count; i++) xref.Append(offsets[i].ToString("D10")).Append(" 00000 n \n");
        xref.Append($"trailer\n<</Size {objs.Count + 1}/Root 1 0 R>>\nstartxref\n{xrefPos}\n%%EOF\n");
        body.Write(Latin1(xref.ToString()));
        var pdf = body.ToArray();

        // 3) Locate the /Contents hex and the /ByteRange field, compute the range.
        int hexStart = IndexOf(pdf, Latin1("/Contents <")) + Latin1("/Contents <").Length;  // first hex digit
        int lt = hexStart - 1;                 // the '<'
        int gtPlusOne = hexStart + ContentsHexLen + 1;  // just after the '>'
        int a = lt;                            // first segment [0, a)
        int b = gtPlusOne;                     // second segment [b, len-b)
        int len = pdf.Length;
        int brField = IndexOf(pdf, Latin1("/ByteRange [")) + Latin1("/ByteRange [").Length;

        // 4) Patch the ByteRange numbers in place (same field width -> offsets stay valid).
        string br = $"0 {a} {b} {len - b}";
        var brBytes = Latin1(br.PadRight(2 + ByteRangeFieldLen));   // "0 " + 48-wide field
        Array.Copy(brBytes, 0, pdf, brField, brBytes.Length);

        // 5) Sign the two covered segments (everything except the Contents hex + brackets).
        var covered = new byte[a + (len - b)];
        Array.Copy(pdf, 0, covered, 0, a);
        Array.Copy(pdf, b, covered, a, len - b);

        var signer = new CmsSigner(leaf)
        {
            DigestAlgorithm = new Oid("2.16.840.1.101.3.4.2.1"),   // SHA-256
            IncludeOption = X509IncludeOption.EndCertOnly,
        };
        signer.SignedAttributes.Add(new Pkcs9SigningTime(DateTime.Parse(c.SignTimeUtc).ToUniversalTime()));
        var cms = new SignedCms(new ContentInfo(covered), detached: true);
        cms.ComputeSignature(signer);
        var der = cms.Encode();

        // 6) Hex-encode the DER into the reserved zeros (trailing zeros are ignored - DER is self-delimiting).
        var hex = Convert.ToHexString(der);
        var hexBytes = Latin1(hex);
        Array.Copy(hexBytes, 0, pdf, hexStart, hexBytes.Length);

        // 7) Optionally tamper: append visible bytes AFTER %%EOF so ByteRange no longer covers the file.
        if (c.TamperAppend)
        {
            var extra = Latin1("\n% appended after signing - tamper marker\n");
            var bigger = new byte[pdf.Length + extra.Length];
            Array.Copy(pdf, bigger, pdf.Length);
            Array.Copy(extra, 0, bigger, pdf.Length, extra.Length);
            pdf = bigger;
        }
        return pdf;
    }

    // ========================================================================
    //  Truth extraction: re-parse a finished PDF the way the Clarion side must.
    // ========================================================================
    record Identity(string SubjectCN, string SubjectO, string SubjectOU, string SubjectEmail,
                    string IssuerCN, string SignTimeUtc, string Name, string Reason, string Location,
                    string SubFilter, bool ByteRangeCoversFile);

    static Identity ExtractTruth(byte[] pdf)
    {
        // /Contents hex -> DER (trim to the DER object's real length).
        int hexStart = IndexOf(pdf, Latin1("/Contents <")) + Latin1("/Contents <").Length;
        int hexEnd = hexStart; while (pdf[hexEnd] != (byte)'>') hexEnd++;
        var hex = Latin1ToString(pdf, hexStart, hexEnd - hexStart).TrimEnd('0');
        if (hex.Length % 2 == 1) hex += "0";
        var der = Convert.FromHexString(hex);
        der = der[..DerTotalLen(der)];

        var cms = new SignedCms();
        cms.Decode(der);
        var si = cms.SignerInfos[0];
        var cert = si.Certificate!;
        string cn  = NamePart(cert.SubjectName, "CN");
        string o   = NamePart(cert.SubjectName, "O");
        string ou  = NamePart(cert.SubjectName, "OU");
        string em  = NamePart(cert.SubjectName, "E");   // emailAddress RDN
        string ica = NamePart(cert.IssuerName, "CN");

        string st = "";
        foreach (CryptographicAttributeObject a in si.SignedAttributes)
            if (a.Oid?.Value == "1.2.840.113549.1.9.5" && a.Values[0] is Pkcs9SigningTime t)
                st = t.SigningTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");

        string name = DictStr(pdf, "/Name(");
        string reason = DictStr(pdf, "/Reason(");
        string loc = DictStr(pdf, "/Location(");
        string sub = DictName(pdf, "/SubFilter/");

        // ByteRange coverage: does [0,a)+[b,len-b) span the entire current file?
        var br = ByteRange(pdf);
        bool covers = br is { } r && r[0] == 0 && (r[2] + r[3] == pdf.Length);

        return new Identity(cn, o, ou, em, ica, st, name, reason, loc, sub, covers);
    }

    // ========================================================================
    //  Commands
    // ========================================================================
    static int Vectors(string dir)
    {
        Directory.CreateDirectory(dir);
        var manifest = new StringBuilder();
        foreach (var c in Cases)
        {
            using var ca = MakeCa(c.IssuerCN);
            using var leaf = MakeLeaf(c, ca);
            var pdf = BuildSignedPdf(c, leaf);
            File.WriteAllBytes(Path.Combine(dir, $"{c.Id}.pdf"), pdf);
            File.WriteAllText(Path.Combine(dir, $"{c.Id}.expected.txt"), Format(ExtractTruth(pdf)));
            manifest.AppendLine($"{c.Id}.pdf");
        }
        File.WriteAllText(Path.Combine(dir, "manifest.txt"), manifest.ToString());
        Console.WriteLine($"wrote {Cases.Length} signed-PDF fixtures + expected truth to {dir}");
        return 0;
    }

    static int ParseCmd(string path)
    {
        Console.WriteLine(Format(ExtractTruth(File.ReadAllBytes(path))));
        return 0;
    }

    static int Verify(string dir)
    {
        int fail = 0;
        foreach (var line in File.ReadAllLines(Path.Combine(dir, "manifest.txt")))
        {
            var id = Path.GetFileNameWithoutExtension(line.Trim());
            if (id.Length == 0) continue;
            var exp = File.ReadAllText(Path.Combine(dir, $"{id}.expected.txt")).Trim();
            var actPath = Path.Combine(dir, $"{id}.actual.txt");
            if (!File.Exists(actPath)) { Console.WriteLine($"MISSING {id}.actual.txt (run Clarion first)"); fail++; continue; }
            var act = File.ReadAllText(actPath).Trim();
            if (Norm(exp) == Norm(act)) Console.WriteLine($"PASS {id}");
            else { Console.WriteLine($"FAIL {id}\n--- expected ---\n{exp}\n--- actual ---\n{act}"); fail++; }
        }
        Console.WriteLine(fail == 0 ? "ALL PASS" : $"{fail} FAILED");
        return fail == 0 ? 0 : 1;
    }

    static int SelfCheck()
    {
        foreach (var c in Cases)
        {
            using var ca = MakeCa(c.IssuerCN);
            using var leaf = MakeLeaf(c, ca);
            var id = ExtractTruth(BuildSignedPdf(c, leaf));
            bool ok = id.SubjectCN == c.SubjectCN && id.IssuerCN == c.IssuerCN
                   && id.SubjectEmail == c.SubjectEmail && id.Reason == c.Reason
                   && id.ByteRangeCoversFile == !c.TamperAppend;
            Console.WriteLine($"{(ok ? "ok  " : "FAIL")} {c.Id}: {id.SubjectCN} / {id.IssuerCN} / covers={id.ByteRangeCoversFile}");
            if (!ok) return 1;
        }
        Console.WriteLine("selfcheck OK");
        return 0;
    }

    // ========================================================================
    //  Helpers
    // ========================================================================
    static string Format(Identity i) => string.Join("\n", new[]
    {
        $"SubjectCN={i.SubjectCN}",
        $"SubjectO={i.SubjectO}",
        $"SubjectOU={i.SubjectOU}",
        $"SubjectEmail={i.SubjectEmail}",
        $"IssuerCN={i.IssuerCN}",
        $"SignTimeUtc={i.SignTimeUtc}",
        $"Name={i.Name}",
        $"Reason={i.Reason}",
        $"Location={i.Location}",
        $"SubFilter={i.SubFilter}",
        $"ByteRangeCoversFile={(i.ByteRangeCoversFile ? 1 : 0)}",
    });

    static string Norm(string s) => string.Join("\n",
        s.Replace("\r", "").Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0));

    static string NamePart(X500DistinguishedName dn, string key)
    {
        // X500 RDNs, parsed from DER so we get exact attribute values (commas/quotes intact).
        var reader = new AsnReader(dn.RawData, AsnEncodingRules.DER);
        var seq = reader.ReadSequence();
        var oids = new Dictionary<string, string> {
            ["2.5.4.3"] = "CN", ["2.5.4.10"] = "O", ["2.5.4.11"] = "OU",
            ["2.5.4.6"] = "C", ["1.2.840.113549.1.9.1"] = "E" };
        while (seq.HasData)
        {
            var rdnSet = seq.ReadSetOf();
            while (rdnSet.HasData)
            {
                var atv = rdnSet.ReadSequence();
                var oid = atv.ReadObjectIdentifier();
                var val = atv.ReadCharacterString(PeekStringTag(atv));
                if (oids.TryGetValue(oid, out var k) && k == key) return val;
            }
        }
        return "";
    }
    static UniversalTagNumber PeekStringTag(AsnReader r)
    {
        var t = r.PeekTag();
        return (UniversalTagNumber)t.TagValue;
    }

    static int DerTotalLen(byte[] der)
    {
        // tag (1 byte here) + length octets + content
        int i = 1;
        int b = der[i++];
        if (b < 0x80) return i + b;
        int n = b & 0x7F, len = 0;
        for (int k = 0; k < n; k++) len = (len << 8) | der[i++];
        return i + len;
    }

    static int[]? ByteRange(byte[] pdf)
    {
        int p = IndexOf(pdf, Latin1("/ByteRange ["));
        if (p < 0) return null;
        p += "/ByteRange [".Length;
        var nums = new List<int>();
        var cur = new StringBuilder();
        while (pdf[p] != (byte)']')
        {
            char ch = (char)pdf[p++];
            if (char.IsDigit(ch)) cur.Append(ch);
            else if (cur.Length > 0) { nums.Add(int.Parse(cur.ToString())); cur.Clear(); }
        }
        if (cur.Length > 0) nums.Add(int.Parse(cur.ToString()));
        return nums.Count == 4 ? nums.ToArray() : null;
    }

    static string DictStr(byte[] pdf, string key)
    {
        int p = IndexOf(pdf, Latin1(key));
        if (p < 0) return "";
        p += key.Length;
        var sb = new StringBuilder();
        while (pdf[p] != (byte)')')
        {
            if (pdf[p] == (byte)'\\') p++;   // unescape
            sb.Append((char)pdf[p++]);
        }
        return sb.ToString();
    }

    static string DictName(byte[] pdf, string key)
    {
        int p = IndexOf(pdf, Latin1(key));
        if (p < 0) return "";
        p += key.Length;
        var sb = new StringBuilder();
        while (p < pdf.Length && pdf[p] != (byte)'/' && pdf[p] != (byte)'>' && !char.IsWhiteSpace((char)pdf[p]))
            sb.Append((char)pdf[p++]);
        return sb.ToString();
    }

    static string Esc(string s) => s.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)");

    static byte[] Latin1(string s) => Encoding.Latin1.GetBytes(s);
    static string Latin1ToString(byte[] b, int off, int len) => Encoding.Latin1.GetString(b, off, len);

    static int IndexOf(byte[] hay, byte[] needle, int start = 0)
    {
        for (int i = start; i <= hay.Length - needle.Length; i++)
        {
            int j = 0; while (j < needle.Length && hay[i + j] == needle[j]) j++;
            if (j == needle.Length) return i;
        }
        return -1;
    }
}
