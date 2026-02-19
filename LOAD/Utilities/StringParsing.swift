import Foundation

extension String {
    func parseArtists() -> [String] {
        let separators = [" & ", " feat. ", " vs. ", " x ", " and ", " with ", " presents ", ", ", " ft. "," feat ", " pres. " ]
        var tempString = self.replacingOccurrences(of: ",", with: ", ")
        
        for separator in separators {
            tempString = tempString.replacingOccurrences(of: separator, with: ", ", options: .caseInsensitive)
        }
        
        return tempString.components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func parseTitleAndMix() -> (title: String, mix: String?) {
        // 1. Initial cleaning of unwanted phrases and whitespace.
        var cleanTitle = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let unwantedSubstrings = ["Local File", "myfreemp3.vip"]
        for unwanted in unwantedSubstrings {
            cleanTitle = cleanTitle.replacingOccurrences(of: unwanted, with: "", options: .caseInsensitive)
        }
        
        // Trim whitespace that might be left after removals.
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        var mix: String? = nil

        // 2. Improved mix extraction logic.
        // This regex looks for text in parentheses () or square brackets [] that contains common mix-related keywords.
        // This is more reliable than just taking any parenthesized text.
        let keywords = [
            "Mix", "Edit", "Remix", "Club", "Version", "Dub", "Vocal",
            "Instrumental", "Bootleg", "Cut", "Rework", "Redo", "VIP",
            "Flip", "Extended", "Radio", "Original"
        ]
        let keywordPattern = keywords.joined(separator: "|")
        
        // The regex pattern is case-insensitive for the keywords.
        // It finds all occurrences of `(...)` or `[...]` that contain a keyword.
        // Example: "Song Title (Intro) [Extended Mix]" -> It will find "[Extended Mix]"
        let regexPattern = #"\s?[(\[]([^(\[]*?(?i:\#(keywordPattern))[^)\]]*)[)\]]"#

        guard let regex = try? NSRegularExpression(pattern: regexPattern) else {
            // If regex fails, return the cleaned title without a mix.
            return (title: cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "-"))), mix: nil)
        }

        let range = NSRange(cleanTitle.startIndex..<cleanTitle.endIndex, in: cleanTitle)
        let matches = regex.matches(in: cleanTitle, options: [], range: range)
        
        // We assume the last match in the string is the true mix name.
        if let lastMatch = matches.last {
            // Extract the mix name (from the first capture group).
            if let mixRange = Range(lastMatch.range(at: 1), in: cleanTitle) {
                mix = String(cleanTitle[mixRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Remove the entire matched part (the full range of the match) from the title.
            if let fullMatchRange = Range(lastMatch.range, in: cleanTitle) {
                cleanTitle.removeSubrange(fullMatchRange)
            }
        }

        // 3. Final cleanup of the title.
        // This removes any trailing characters like " - " that might be left after stripping the mix.
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "- ")))
        
        // Regarding the original comment: "Handle cases like 'Title (Mix) - Artist'".
        // This upgraded logic correctly extracts "(Mix)" as the mix and leaves "Title  - Artist"
        // as the title. It's the responsibility of the calling code (e.g., the API service)
        // to know the artist's name and use only the title part for searching if needed.
        // This function's goal is to robustly separate the mix name, which it now does for more cases.
        
        return (title: cleanTitle, mix: mix)
    }
}
