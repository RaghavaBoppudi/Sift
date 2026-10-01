import Foundation

/// Turns a URL into its registrable domain (eTLD+1): "accounts.meta.com" -> "meta.com".
///
/// KNOWN LIMITATION: not a full Public Suffix List. It hardcodes common two-label suffixes
/// so "bbc.co.uk" and "bank.co.uk" don't both collapse to "co.uk". Anything missing from the
/// list below misgroups. Replace with a bundled PSL file (publicsuffix.org) before relying
/// on this beyond personal use.
public enum DomainResolver {

    private static let twoLabelSuffixes: Set<String> = [
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
        guard var host = url.host?.lowercased() else { return nil }
        if host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty else { return nil }

        // IPs and bare hostnames have no registrable domain; the whole host is the identity.
        // Without this, 192.168.1.1 and 10.0.1.1 would both resolve to "1.1".
        guard !isIPAddress(host) else { return host }
        let labels = host.split(separator: ".")
        guard labels.count >= 2 else { return host }

        let lastTwo = labels.suffix(2).joined(separator: ".")
        if labels.count >= 3, twoLabelSuffixes.contains(lastTwo) {
            return labels.suffix(3).joined(separator: ".")
        }
        return lastTwo
    }

    /// "meta" from "meta.com", "bbc" from "bbc.co.uk". IPs keep their full address so
    /// distinct IPs never share a label.
    static func brandLabel(from registrableDomain: String) -> String {
        if isIPAddress(registrableDomain) { return registrableDomain }
        return registrableDomain.split(separator: ".").first.map(String.init) ?? registrableDomain
    }

    private static func isIPAddress(_ host: String) -> Bool {
        host.contains(":") || host.split(separator: ".").allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}
