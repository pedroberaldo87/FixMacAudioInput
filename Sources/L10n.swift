import Foundation

/// Localized string lookup. Keys live in Resources/Localization/<lang>.lproj/Localizable.strings.
/// English is the development language and the fallback.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String(format: format, locale: Locale.current, arguments: args)
}
