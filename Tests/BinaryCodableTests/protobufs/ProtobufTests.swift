// Copyright 2019-present the BinaryCodable authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import BinaryCodable
import Foundation
import XCTest

class ProtobufTests: XCTestCase {
  private let environment = TestConfig.environment

  func testProtoCompiler() throws {
    // Either set a PROTOC_PATH environment variable to the location of the protoc binary,
    // or place the protoc binary in <repo root>/bin/
    //
    // You can run the following from the <repo root>:
    //
    //     wget https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/protoc-3.6.1-osx-x86_64.zip
    //     unzip protoc-3.6.1-osx-x86_64.zip
    //
    XCTAssertTrue(FileManager.default.fileExists(atPath: environment.protocPath))
  }

  func testProtoCompilerPipeline() throws {
    // Given
    let data = try compileProto(definition: """
      message int_value {
        int32 int_value = 1;
      }
      """, message: "int_value", content: """
      int_value: 1
      """)

    // Then
    XCTAssertEqual([UInt8](data), [0x08, 0x01])
  }

  // MARK: int32

  func testInt320Decoding() throws {
    // Given
    let data = try compileProto(definition: """
      message int_value {
        int32 int_value = 1;
      }
      """, message: "int_value", content: """
      int_value: 0
      """)
    let decoder = BinaryDataDecoder()

    // When
    do {
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testInt32PositiveValueDecoding() throws {
    // Given
    let valuesToTest: [Int32] = [
      1, 127, // 1 byte range
      128, 16383, // 2 byte range
      16384, 2097151, // 3 byte range
      2097152, 268435455, // 4 byte range
      268435456, Int32.max, // 5 byte range
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          int32 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(value)))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  func testInt32OverflowFailsToCompile() throws {
    // Given
    let value = UInt32.max

    XCTAssertThrowsError(try compileProto(definition: """
      message int_value {
        int32 int_value = 1;
      }
      """, message: "int_value", content: """
      int_value: \(value)
      """), "Failed to compile") { error in
      XCTAssertTrue(error is ProtoCompilerError)
    }
  }

  func testInt32NegativeValueDecoding() throws {
    // Given
    let valuesToTest: [Int32] = [
      -1, -127,
      -128, -16383,
      -16384, -2097151,
      -2097152, -268435455,
      -268435456, Int32.min,
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          int32 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(bitPattern: Int64(value))))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  func testMultipleInt32Decoding() throws {
    // Given
    let data = try compileProto(definition: """
      message int_value {
        int32 first_value = 1;
        int32 second_value = 2;
        int32 third_value = 3;
      }
      """, message: "int_value", content: """
      first_value: 1
      second_value: 128
      third_value: 268435456
      """)
    let decoder = BinaryDataDecoder()

    // When
    do {
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages, [
        ProtoMessage(fieldNumber: 1, value: .varint(rawValue: 1)),
        ProtoMessage(fieldNumber: 2, value: .varint(rawValue: 128)),
        ProtoMessage(fieldNumber: 3, value: .varint(rawValue: 268435456)),
        ])
      XCTAssertEqual(messages.count, 3)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  // MARK: int64

  func testInt640Decoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message int_value {
          int64 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: 0
        """)
      let decoder = BinaryDataDecoder()

    // When
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testInt64PositiveValueDecoding() throws {
    // Given
    let valuesToTest: [Int64] = [
      1, 127, // 1 byte range
      128, 16383, // 2 byte range
      16384, 2097151, // 3 byte range
      2097152, 268435455, // 4 byte range
      268435456, 34359738367, // 5 byte range
      34359738368, 4398046511103, // 6 byte range
      4398046511104, 562949953421311, // 7 byte range
      562949953421312, 72057594037927935, // 8 byte range
      72057594037927936, Int64.max, // 9 byte range
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          int64 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(value)))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  func testInt64NegativeValueDecoding() throws {
    // Given
    let valuesToTest: [Int64] = [
      -1, -127,
      -128, -16383,
      -16384, -2097151,
      -2097152, -268435455,
      -268435456, -34359738367,
      -34359738368, -4398046511103,
      -4398046511104, -562949953421311,
      -562949953421312, -72057594037927935,
      -72057594037927936, Int64.min
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          int64 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(bitPattern: Int64(value))))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  // MARK: sint32

  func testSInt320Decoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message int_value {
          sint32 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: 0
        """)
      let decoder = BinaryDataDecoder()

      // When
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testSInt32PositiveValueDecoding() throws {
    // Given
    let valuesToTest: [Int32] = [
      1, 127, // 1 byte range
      128, 16383, // 2 byte range
      16384, 2097151, // 3 byte range
      2097152, 268435455, // 4 byte range
      268435456, Int32.max, // 5 byte range
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          sint32 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        // sint values will be zig-zag encoded.
        // https://developers.google.com/protocol-buffers/docs/encoding#signed-integers
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(UInt32(bitPattern: (value << 1) ^ (value >> 31)))))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  func testSInt32NegativeValueDecoding() throws {
    // Given
    let valuesToTest: [Int32] = [
      -1, -127,
      -128, -16383,
      -16384, -2097151,
      -2097152, -268435455,
      -268435456, Int32.min,
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message int_value {
          sint32 int_value = 1;
        }
        """, message: "int_value", content: """
        int_value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        // sint values will be zig-zag encoded.
        // https://developers.google.com/protocol-buffers/docs/encoding#signed-integers
        XCTAssertEqual(message.value, .varint(rawValue: UInt64(UInt32(bitPattern: (value << 1) ^ (value >> 31)))))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  // MARK: fixed32

  func testFixed320Decoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message value {
          fixed32 value = 1;
        }
        """, message: "value", content: """
        value: 0
        """)
      let decoder = BinaryDataDecoder()

      // When
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testFixed32ValueDecoding() throws {
    // Given
    let valuesToTest: [UInt32] = [
      1, UInt32.max
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message value {
          fixed32 value = 1;
        }
        """, message: "value", content: """
        value: \(value)
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .fixed32(rawValue: value))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  // MARK: float

  func testFloat0Decoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message float_value {
          float float_value = 1;
        }
        """, message: "float_value", content: """
        float_value: 0
        """)
      let decoder = BinaryDataDecoder()

      // When
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testFloatValueDecoding() throws {
    // Given
    let valuesToTest: [Float] = [
      -Float.greatestFiniteMagnitude, -3.14159, -1, 1, 3.14159, Float.greatestFiniteMagnitude,
      ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message float_value {
          float float_value = 1;
        }
        """, message: "float_value", content: """
        float_value: \(String(format: "%0.20f", value))
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)

        XCTAssertEqual(message.value, .fixed32(rawValue: value.bitPattern))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  // MARK: double

  func testDouble0Decoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message value {
          double value = 1;
        }
        """, message: "value", content: """
        value: 0
        """)
      let decoder = BinaryDataDecoder()

      // When
      let messages = try decoder.decode([ProtoMessage].self, from: data)

      // Then
      XCTAssertEqual(messages.count, 0)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  func testDoubleValueDecoding() throws {
    // Given
    let valuesToTest: [Double] = [
      -Double.greatestFiniteMagnitude, -3.14159, -1, 1, 3.14159, Double.greatestFiniteMagnitude,
    ]

    for value in valuesToTest {
      let data = try compileProto(definition: """
        message value {
          double value = 1;
        }
        """, message: "value", content: """
        value: \(String(format: "%0.20f", value))
        """)
      let decoder = BinaryDataDecoder()

      // When
      do {
        let messages = try decoder.decode([ProtoMessage].self, from: data)

        // Then
        XCTAssertEqual(messages.count, 1)
        guard let message = messages.first else {
          continue
        }
        XCTAssertEqual(message.fieldNumber, 1)
        XCTAssertEqual(message.value, .fixed64(rawValue: value.bitPattern))
      } catch let error {
        XCTFail("Value \(value): \(String(describing: error))")
      }
    }
  }

  // MARK: Generated messages

  func testGeneratedMessageDecoding() throws {
    // Given
    do {
      let data = try compileProto(definition: """
        message embedded {
          int32 int32_value = 1;
        }
        message value {
          double double_value = 1;
          float float_value = 2;
          int32 int32_value = 3;
          int64 int64_value = 4;
          uint32 uint32_value = 5;
          uint64 uint64_value = 6;
          sint32 sint32_value = 7;
          sint32 sint64_value = 8;
          fixed32 fixed32_value = 9;
          fixed64 fixed64_value = 10;
          bool bool_value = 13;
          string string_value = 14;
          bytes bytes_value = 15;
          embedded embedded_value = 16;
          int32 missing_value = 20;
        }
        """, message: "value", content: """
        double_value: 1.34159
        float_value: 1.5234
        int32_value: 1
        int64_value: \(Int64.max)
        uint32_value: \(UInt32.max)
        uint64_value: \(UInt64.max)
        sint32_value: 268435456
        sint64_value: 268435456
        fixed32_value: \(UInt32.max)
        fixed64_value: \(UInt64.max)
        bool_value: true
        string_value: "Some string"
        bytes_value: "\\000\\001\\002"
        embedded_value {
          int32_value: 5678
        }
        """)
      let decoder = ProtoDecoder()

      // When
      let message = try decoder.decode(Message.self, from: data)

      // Then
      XCTAssertEqual(message.doubleValue, 1.34159)
      XCTAssertEqual(message.floatValue, 1.5234)
      XCTAssertEqual(message.int32Value, 1)
      XCTAssertEqual(message.int64Value, Int64.max)
      XCTAssertEqual(message.uint32Value, UInt32.max)
      XCTAssertEqual(message.uint64Value, UInt64.max)
      XCTAssertEqual(message.sint32Value, 268435456)
      XCTAssertEqual(message.sint64Value, 268435456)
      XCTAssertEqual(message.fixed32Value, UInt32.max)
      XCTAssertEqual(message.fixed64Value, UInt64.max)
      XCTAssertNotNil(message.boolValue)
      XCTAssertEqual(message.stringValue, "Some string")
      XCTAssertNotNil(message.bytesValue)
      if let bytesValue = message.bytesValue {
        XCTAssertEqual([UInt8](bytesValue), [0, 1, 2])
      }
      if let boolValue = message.boolValue {
        XCTAssertTrue(boolValue)
      }
      XCTAssertNil(message.missingValue)
      XCTAssertEqual(message.embedded?.int32Value, 5678)
    } catch let error {
      XCTFail(String(describing: error))
    }
  }

  private func compileProto(definition: String, message: String, content: String) throws -> Data {
    let input = temporaryFile()
    let proto = temporaryFile()
    let output = temporaryFile()
    let errors = temporaryFile()

    let package = "\(type(of: self))"
    let header = """
    syntax = "proto3";

    package \(package);

    """
    try (header + definition).write(to: proto, atomically: true, encoding: .utf8)
    try content.write(to: input, atomically: true, encoding: .utf8)

    let task = Process()
    task.launchPath = environment.protocPath
    task.standardInput = try FileHandle(forReadingFrom: input)
    task.standardOutput = try FileHandle(forWritingTo: output)
    task.standardError = try FileHandle(forWritingTo: errors)
    task.arguments = [
      "--encode",
      "\(package).\(message)",
      "-I",
      proto.deletingLastPathComponent().absoluteString.replacingOccurrences(of: "file://", with: ""),
      proto.absoluteString.replacingOccurrences(of: "file://", with: "")
    ]
    task.launch()
    task.waitUntilExit()

    let errorText = try String(contentsOf: errors)
    if !errorText.isEmpty {
      throw ProtoCompilerError.producedErrorOutput(stderr: errorText)
    }

    return try Data(contentsOf: output)
  }
}

private enum ProtoCompilerError: Error {
  case producedErrorOutput(stderr: String)
}

private func temporaryFile() -> URL {
  let template = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("file.XXXXXX") as NSURL
  var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
  template.getFileSystemRepresentation(&buffer, maxLength: buffer.count)
  let fd = mkstemp(&buffer)
  guard fd != -1 else {
    preconditionFailure("Unable to create temporary file.")
  }
  return URL(fileURLWithFileSystemRepresentation: buffer, isDirectory: false, relativeTo: nil)
}

private struct TestConfig {
  var testAgainstProtoc = true
  var protocPath: String = {

    return URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("bin")
      .appendingPathComponent("protoc")
      .absoluteString
      .replacingOccurrences(of: "file://", with: "")
  }()

  static var environment: TestConfig {
    var config = TestConfig()
    if let protocPath = getEnvironmentVariable(named: "PROTOC_PATH") {
      config.protocPath = protocPath
    }
    return config
  }
}

private func getEnvironmentVariable(named name: String) -> String? {
  if let environmentValue = getenv(name) {
    return String(cString: environmentValue)
  } else {
    return nil
  }
}
