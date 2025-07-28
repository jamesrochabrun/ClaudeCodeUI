import Foundation

/// Binary search function that searches for a target value in a sorted array
/// - Parameters:
///   - array: A sorted array of comparable elements
///   - target: The value to search for
/// - Returns: The index of the target if found, nil otherwise
func binarySearch<T: Comparable>(_ array: [T], target: T) -> Int? {
    var left = 0
    var right = array.count - 1
    
    while left <= right {
        let mid = left + (right - left) / 2
        
        if array[mid] == target {
            return mid
        } else if array[mid] < target {
            left = mid + 1
        } else {
            right = mid - 1
        }
    }
    
    return nil
}

// Example usage:
let numbers = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
if let index = binarySearch(numbers, target: 7) {
    print("Found 7 at index \(index)")
} else {
    print("7 not found in the array")
}

let strings = ["apple", "banana", "cherry", "date", "elderberry"]
if let index = binarySearch(strings, target: "cherry") {
    print("Found 'cherry' at index \(index)")
} else {
    print("'cherry' not found in the array")
}