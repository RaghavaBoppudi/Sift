import Foundation

/// Turns a URL into its registrable domain (eTLD+1) — e.g. "accounts.meta.com" -> "meta.com".
///
/// ⚠️ KNOWN LIMITATION, not yet fixed: this is NOT a full Public Suffix List implementation.
/// It hardcodes the common two-label suffixes (co.uk, com.au, etc.) that would otherwise
/// misgroup — e.g. without this list, "bbc.co.uk" and "bank.co.uk" would both incorrectly
/// resolve to "co.uk" and get treated as the same site. The list below is NOT exhaustive.
/// Before relying on this for anything beyond your own testing, swap this out for a real
/// bundled PSL file (publicsuffix.org publishes one) parsed properly. This is a placeholder
/// that gets the common cases right, not the finished implementation.
public enum DomainResolver {

    private static let knownTwoLabelSuffixes: Set<String> = [
        "co.uk", "org.uk", "gov.uk", "ac.uk", "me.uk", "ltd.uk", "plc.uk",
        "com.au", "net.au", "org.au", "gov.au", "edu.au",
        "co.in", "net.in", "org.in", "gov.in",
        "co.jp", "ne.jp", "or.jp", "ac.jp",
        "com.br", "net.br", "org.br",
        "co.nz", "net.nz", "org.nz",
        "co.za",
        "com.cn", "net.cn", "org.cn",
        "com.mx",
        "com.sg"
    ]

    public static func registrableDomain(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }

        // Strip a trailing dot if present (FQDN notation).
        let cleanHost = host.hasSuffix(".") ? String(host.dropLast()) : host

        let labels = cleanHost.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return cleanHost } // e.g. "localhost" — nothing to strip

        let lastTwo = labels.suffix(2).joined(separator: ".")
        if labels.count >= 3, knownTwoLabelSuffixes.contains(lastTwo) {
            // Need three labels to get past the known two-label public suffix.
            return labels.suffix(3).joined(separator: ".")
        }

        return lastTwo
    }

    /// The brand-ish label of an already-resolved registrable domain — "meta" from
    /// "meta.com", "bbc" from "bbc.co.uk". Used only for brand-prefix matching in
    /// ConflictAnalyzer (e.g. treating meta.com and metacareers.com as related), not for
    /// eTLD+1 resolution itself.
    public static func brandLabel(from registrableDomain: String) -> String {
        registrableDomain.split(separator: ".").first.map(String.init) ?? registrableDomain
    }
}
