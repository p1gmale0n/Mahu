import Foundation

enum ConfigJSONPreprocessorError: Error, Equatable {
    case unterminatedBlockComment
}

enum ConfigJSONPreprocessor {
    static func preprocess(_ source: String) throws -> String {
        let sourceWithoutComments = try stripComments(from: source)
        return removeTrailingCommas(from: sourceWithoutComments)
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
