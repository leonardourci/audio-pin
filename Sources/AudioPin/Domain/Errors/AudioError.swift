import Foundation

enum AudioError: Error {
    case coreAudio(OSStatus)
    case propertyNotFound
}
