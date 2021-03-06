//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
//
// SocketChannelTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension SocketChannelTest {

   static var allTests : [(String, (SocketChannelTest) -> () throws -> Void)] {
      return [
                ("testAsyncSetOption", testAsyncSetOption),
                ("testDelayedConnectSetsUpRemotePeerAddress", testDelayedConnectSetsUpRemotePeerAddress),
                ("testAcceptFailsWithECONNABORTED", testAcceptFailsWithECONNABORTED),
                ("testAcceptFailsWithEMFILE", testAcceptFailsWithEMFILE),
                ("testAcceptFailsWithENFILE", testAcceptFailsWithENFILE),
                ("testAcceptFailsWithENOBUFS", testAcceptFailsWithENOBUFS),
                ("testAcceptFailsWithENOMEM", testAcceptFailsWithENOMEM),
                ("testAcceptFailsWithEFAULT", testAcceptFailsWithEFAULT),
                ("testSetGetOptionClosedServerSocketChannel", testSetGetOptionClosedServerSocketChannel),
                ("testConnect", testConnect),
           ]
   }
}

