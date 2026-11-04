import Foundation

/// Localised string from a literal; the literal is extracted into the String Catalog at build time.
func loc(_ value: String.LocalizationValue) -> String { String(localized: value) }

/// Runtime lookup for strings that come from data (content.json, enum raw values).
func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
