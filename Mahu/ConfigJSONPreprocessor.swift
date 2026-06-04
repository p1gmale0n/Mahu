import Foundation

enum ConfigJSONPreprocessorError: Error, Equatable {
    case unterminatedBlockComment
}

enum ConfigJSONPreprocessor {
    static func preprocess(_ rawData: Data) throws -> Data {
        let decodingContext = DecodingError.Context(
            codingPath: [],
            debugDescription: "Config data must be valid UTF-8, UTF-16, or UTF-32 JSON text."
        )
        let rawConfigText = try decodeJSONText(rawData, context: decodingContext)
        let sanitizedConfigText: String
        do {
            sanitizedConfigText = try preprocess(rawConfigText)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "Config JSONC preprocessing failed: \(error)"
                )
            )
        }

        guard let sanitizedConfigData = sanitizedConfigText.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(decodingContext)
        }

        return sanitizedConfigData
    }

    static func preprocess(_ source: String) throws -> String {
        let sourceWithoutComments = try stripComments(from: source)
        return removeTrailingCommas(from: sourceWithoutComments)
    }

    private static func decodeJSONText(_ rawData: Data, context: DecodingError.Context) throws -> String {
        let encoding = jsonTextEncoding(for: rawData)
        guard let rawConfigText = String(data: rawData, encoding: encoding) else {
            throw DecodingError.dataCorrupted(context)
        }

        return stripLeadingByteOrderMarkIfPresent(from: rawConfigText)
    }

    private static func jsonTextEncoding(for rawData: Data) -> String.Encoding {
        let bytes = Array(rawData.prefix(4))

        if bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return .utf32BigEndian
        }

        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return .utf32LittleEndian
        }

        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        }

        if bytes.starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }

        if bytes.starts(with: [0xFF, 0xFE]) {
            return .utf16LittleEndian
        }

        guard bytes.count == 4 else {
            return .utf8
        }

        switch (bytes[0], bytes[1], bytes[2], bytes[3]) {
        case (0x00, 0x00, 0x00, _):
            return .utf32BigEndian
        case (_, 0x00, 0x00, 0x00):
            return .utf32LittleEndian
        case (0x00, _, 0x00, _):
            return .utf16BigEndian
        case (_, 0x00, _, 0x00):
            return .utf16LittleEndian
        default:
            return .utf8
        }
    }

    private static func stripLeadingByteOrderMarkIfPresent(from source: String) -> String {
        guard source.first == "\u{FEFF}" else {
            return source
        }

        return String(source.dropFirst())
    }

    private static func stripComments(from source: String) throws -> String {
        var output = String()
        var index = source.startIndex
        var isInsideString = false
        var isEscapingStringCharacter = false
        var isInsideLineComment = false
        var isInsideBlockComment = false

        while index < source.endIndex {
            let character = source[index]
            let nextIndex = source.index(after: index)
            let nextCharacter = nextIndex < source.endIndex ? source[nextIndex] : nil

            if isInsideLineComment {
                if character == "\n" || character == "\r" {
                    isInsideLineComment = false
                    output.append(character)
                }

                index = nextIndex
                continue
            }

            if isInsideBlockComment {
                if character == "*" && nextCharacter == "/" {
                    isInsideBlockComment = false
                    index = source.index(after: nextIndex)
                    continue
                }

                if character == "\n" || character == "\r" {
                    output.append(character)
                }

                index = nextIndex
                continue
            }

            if isInsideString {
                output.append(character)

                if isEscapingStringCharacter {
                    isEscapingStringCharacter = false
                } else if character == "\\" {
                    isEscapingStringCharacter = true
                } else if character == "\"" {
                    isInsideString = false
                }

                index = nextIndex
                continue
            }

            if character == "\"" {
                isInsideString = true
                output.append(character)
                index = nextIndex
                continue
            }

            if character == "/" && nextCharacter == "/" {
                isInsideLineComment = true
                index = source.index(after: nextIndex)
                continue
            }

            if character == "/" && nextCharacter == "*" {
                output.append(" ")
                isInsideBlockComment = true
                index = source.index(after: nextIndex)
                continue
            }

            output.append(character)
            index = nextIndex
        }

        if isInsideBlockComment {
            throw ConfigJSONPreprocessorError.unterminatedBlockComment
        }

        return output
    }

    private static func removeTrailingCommas(from source: String) -> String {
        var output = String()
        var index = source.startIndex
        var isInsideString = false
        var isEscapingStringCharacter = false

        while index < source.endIndex {
            let character = source[index]

            if isInsideString {
                output.append(character)

                if isEscapingStringCharacter {
                    isEscapingStringCharacter = false
                } else if character == "\\" {
                    isEscapingStringCharacter = true
                } else if character == "\"" {
                    isInsideString = false
                }

                index = source.index(after: index)
                continue
            }

            if character == "\"" {
                isInsideString = true
                output.append(character)
                index = source.index(after: index)
                continue
            }

            if character == ",", let nextSignificantCharacter = nextNonWhitespaceCharacter(in: source, after: index),
               nextSignificantCharacter == "}" || nextSignificantCharacter == "]" {
                index = source.index(after: index)
                continue
            }

            output.append(character)
            index = source.index(after: index)
        }

        return output
    }

    private static func nextNonWhitespaceCharacter(in source: String, after index: String.Index) -> Character? {
        var candidateIndex = source.index(after: index)

        // Trailing-comma detection intentionally ignores only whitespace because comments are already stripped.
        while candidateIndex < source.endIndex, source[candidateIndex].isWhitespace {
            candidateIndex = source.index(after: candidateIndex)
        }

        guard candidateIndex < source.endIndex else {
            return nil
        }

        return source[candidateIndex]
    }
}
