//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: DeviceTransfer.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

struct DeviceTransferProtos_File: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// @required
  var identifier: String = String()

  /// @required
  var relativePath: String = String()

  /// @required
  var estimatedSize: UInt64 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct DeviceTransferProtos_Default: @unchecked Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// @required
  var key: String = String()

  /// @required
  var encodedValue: Data = Data()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct DeviceTransferProtos_Database: @unchecked Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// @required
  var key: Data = Data()

  /// @required
  var database: DeviceTransferProtos_File {
    get {return _database ?? DeviceTransferProtos_File()}
    set {_database = newValue}
  }
  /// Returns true if `database` has been explicitly set.
  var hasDatabase: Bool {return self._database != nil}
  /// Clears the value of `database`. Subsequent reads from it will return its default value.
  mutating func clearDatabase() {self._database = nil}

  /// @required
  var wal: DeviceTransferProtos_File {
    get {return _wal ?? DeviceTransferProtos_File()}
    set {_wal = newValue}
  }
  /// Returns true if `wal` has been explicitly set.
  var hasWal: Bool {return self._wal != nil}
  /// Clears the value of `wal`. Subsequent reads from it will return its default value.
  mutating func clearWal() {self._wal = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _database: DeviceTransferProtos_File? = nil
  fileprivate var _wal: DeviceTransferProtos_File? = nil
}

struct DeviceTransferProtos_Manifest: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// @required
  var grdbSchemaVersion: UInt64 = 0

  var database: DeviceTransferProtos_Database {
    get {return _database ?? DeviceTransferProtos_Database()}
    set {_database = newValue}
  }
  /// Returns true if `database` has been explicitly set.
  var hasDatabase: Bool {return self._database != nil}
  /// Clears the value of `database`. Subsequent reads from it will return its default value.
  mutating func clearDatabase() {self._database = nil}

  var appDefaults: [DeviceTransferProtos_Default] = []

  var standardDefaults: [DeviceTransferProtos_Default] = []

  var files: [DeviceTransferProtos_File] = []

  var estimatedTotalSize: UInt64 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _database: DeviceTransferProtos_Database? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "DeviceTransferProtos"

extension DeviceTransferProtos_File: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".File"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "identifier"),
    2: .same(proto: "relativePath"),
    3: .same(proto: "estimatedSize"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.identifier) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.relativePath) }()
      case 3: try { try decoder.decodeSingularUInt64Field(value: &self.estimatedSize) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.identifier.isEmpty {
      try visitor.visitSingularStringField(value: self.identifier, fieldNumber: 1)
    }
    if !self.relativePath.isEmpty {
      try visitor.visitSingularStringField(value: self.relativePath, fieldNumber: 2)
    }
    if self.estimatedSize != 0 {
      try visitor.visitSingularUInt64Field(value: self.estimatedSize, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: DeviceTransferProtos_File, rhs: DeviceTransferProtos_File) -> Bool {
    if lhs.identifier != rhs.identifier {return false}
    if lhs.relativePath != rhs.relativePath {return false}
    if lhs.estimatedSize != rhs.estimatedSize {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension DeviceTransferProtos_Default: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Default"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "key"),
    2: .same(proto: "encodedValue"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.key) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.encodedValue) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.key.isEmpty {
      try visitor.visitSingularStringField(value: self.key, fieldNumber: 1)
    }
    if !self.encodedValue.isEmpty {
      try visitor.visitSingularBytesField(value: self.encodedValue, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: DeviceTransferProtos_Default, rhs: DeviceTransferProtos_Default) -> Bool {
    if lhs.key != rhs.key {return false}
    if lhs.encodedValue != rhs.encodedValue {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension DeviceTransferProtos_Database: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Database"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "key"),
    2: .same(proto: "database"),
    3: .same(proto: "wal"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.key) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._database) }()
      case 3: try { try decoder.decodeSingularMessageField(value: &self._wal) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if !self.key.isEmpty {
      try visitor.visitSingularBytesField(value: self.key, fieldNumber: 1)
    }
    try { if let v = self._database {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    try { if let v = self._wal {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: DeviceTransferProtos_Database, rhs: DeviceTransferProtos_Database) -> Bool {
    if lhs.key != rhs.key {return false}
    if lhs._database != rhs._database {return false}
    if lhs._wal != rhs._wal {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension DeviceTransferProtos_Manifest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Manifest"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "grdbSchemaVersion"),
    2: .same(proto: "database"),
    3: .same(proto: "appDefaults"),
    4: .same(proto: "standardDefaults"),
    5: .same(proto: "files"),
    6: .same(proto: "estimatedTotalSize"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt64Field(value: &self.grdbSchemaVersion) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._database) }()
      case 3: try { try decoder.decodeRepeatedMessageField(value: &self.appDefaults) }()
      case 4: try { try decoder.decodeRepeatedMessageField(value: &self.standardDefaults) }()
      case 5: try { try decoder.decodeRepeatedMessageField(value: &self.files) }()
      case 6: try { try decoder.decodeSingularUInt64Field(value: &self.estimatedTotalSize) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.grdbSchemaVersion != 0 {
      try visitor.visitSingularUInt64Field(value: self.grdbSchemaVersion, fieldNumber: 1)
    }
    try { if let v = self._database {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    if !self.appDefaults.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.appDefaults, fieldNumber: 3)
    }
    if !self.standardDefaults.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.standardDefaults, fieldNumber: 4)
    }
    if !self.files.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.files, fieldNumber: 5)
    }
    if self.estimatedTotalSize != 0 {
      try visitor.visitSingularUInt64Field(value: self.estimatedTotalSize, fieldNumber: 6)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: DeviceTransferProtos_Manifest, rhs: DeviceTransferProtos_Manifest) -> Bool {
    if lhs.grdbSchemaVersion != rhs.grdbSchemaVersion {return false}
    if lhs._database != rhs._database {return false}
    if lhs.appDefaults != rhs.appDefaults {return false}
    if lhs.standardDefaults != rhs.standardDefaults {return false}
    if lhs.files != rhs.files {return false}
    if lhs.estimatedTotalSize != rhs.estimatedTotalSize {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
