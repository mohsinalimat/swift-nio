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

import XCTest
import Dispatch
@testable import NIO

enum EventLoopFutureTestError : Error {
    case example
}

class EventLoopFutureTest : XCTestCase {
    func testFutureFulfilledIfHasResult() throws {
        let eventLoop = EmbeddedEventLoop()
        let f = EventLoopFuture(eventLoop: eventLoop, result: 5, file: #file, line: #line)
        XCTAssertTrue(f.isFulfilled)
    }

    func testFutureFulfilledIfHasError() throws {
        let eventLoop = EmbeddedEventLoop()
        let f = EventLoopFuture<Void>(eventLoop: eventLoop, error: EventLoopFutureTestError.example, file: #file, line: #line)
        XCTAssertTrue(f.isFulfilled)
    }

    func testAndAllWithAllSuccesses() throws {
        let eventLoop = EmbeddedEventLoop()
        let promises: [EventLoopPromise<Void>] = (0..<100).map { (_: Int) in eventLoop.newPromise() }
        let futures = promises.map { $0.futureResult }

        let fN: EventLoopFuture<Void> = EventLoopFuture<Void>.andAll(futures, eventLoop: eventLoop)
        _ = promises.map { $0.succeed(result: ()) }
        () = try fN.wait()
    }

    func testAndAllWithAllFailures() throws {
        struct E: Error {}
        let eventLoop = EmbeddedEventLoop()
        let promises: [EventLoopPromise<Void>] = (0..<100).map { (_: Int) in eventLoop.newPromise() }
        let futures = promises.map { $0.futureResult }

        let fN: EventLoopFuture<Void> = EventLoopFuture<Void>.andAll(futures, eventLoop: eventLoop)
        _ = promises.map { $0.fail(error: E()) }
        do {
            () = try fN.wait()
            XCTFail("should've thrown an error")
        } catch _ as E {
            /* good */
        } catch let e {
            XCTFail("error of wrong type \(e)")
        }
    }

    func testAndAllWithOneFailure() throws {
        struct E: Error {}
        let eventLoop = EmbeddedEventLoop()
        var promises: [EventLoopPromise<Void>] = (0..<100).map { (_: Int) in eventLoop.newPromise() }
        _ = promises.map { $0.succeed(result: ()) }
        let failedPromise: EventLoopPromise<()> = eventLoop.newPromise()
        failedPromise.fail(error: E())
        promises.append(failedPromise)

        let futures = promises.map { $0.futureResult }

        let fN: EventLoopFuture<Void> = EventLoopFuture<Void>.andAll(futures, eventLoop: eventLoop)
        do {
            () = try fN.wait()
            XCTFail("should've thrown an error")
        } catch _ as E {
            /* good */
        } catch let e {
            XCTFail("error of wrong type \(e)")
        }
    }

    func testThenThrowingWhichDoesNotThrow() {
        let eventLoop = EmbeddedEventLoop()
        var ran = false
        let p: EventLoopPromise<String> = eventLoop.newPromise()
        p.futureResult.map {
            $0.count
        }.thenThrowing {
            1 + $0
        }.whenSuccess {
            ran = true
            XCTAssertEqual($0, 6)
        }
        p.succeed(result: "hello")
        XCTAssertTrue(ran)
    }

    func testThenThrowingWhichDoesThrow() {
        enum DummyError: Error, Equatable {
            case dummyError
        }
        let eventLoop = EmbeddedEventLoop()
        var ran = false
        let p: EventLoopPromise<String> = eventLoop.newPromise()
        p.futureResult.map {
            $0.count
        }.thenThrowing { (x: Int) throws -> Int in
            XCTAssertEqual(5, x)
            throw DummyError.dummyError
        }.map { (x: Int) -> Int in
            XCTFail("shouldn't have been called")
            return x
        }.whenFailure {
            ran = true
            XCTAssertEqual(.some(DummyError.dummyError), $0 as? DummyError)
        }
        p.succeed(result: "hello")
        XCTAssertTrue(ran)
    }

    func testThenIfErrorThrowingWhichDoesNotThrow() {
        enum DummyError: Error, Equatable {
            case dummyError
        }
        let eventLoop = EmbeddedEventLoop()
        var ran = false
        let p: EventLoopPromise<String> = eventLoop.newPromise()
        p.futureResult.map {
            $0.count
        }.thenIfErrorThrowing {
            XCTAssertEqual(.some(DummyError.dummyError), $0 as? DummyError)
            return 5
        }.thenIfErrorThrowing { (_: Error) in
            XCTFail("shouldn't have been called")
            return 5
        }.whenSuccess {
            ran = true
            XCTAssertEqual($0, 5)
        }
        p.fail(error: DummyError.dummyError)
        XCTAssertTrue(ran)
    }

    func testThenIfErrorThrowingWhichDoesThrow() {
        enum DummyError: Error, Equatable {
            case dummyError1
            case dummyError2
        }
        let eventLoop = EmbeddedEventLoop()
        var ran = false
        let p: EventLoopPromise<String> = eventLoop.newPromise()
        p.futureResult.map {
            $0.count
        }.thenIfErrorThrowing { (x: Error) throws -> Int in
            XCTAssertEqual(.some(DummyError.dummyError1), x as? DummyError)
            throw DummyError.dummyError2
        }.map { (x: Int) -> Int in
            XCTFail("shouldn't have been called")
            return x
        }.whenFailure {
            ran = true
            XCTAssertEqual(.some(DummyError.dummyError2), $0 as? DummyError)
        }
        p.fail(error: DummyError.dummyError1)
        XCTAssertTrue(ran)
    }

    func testOrderOfFutureCompletion() throws {
        let eventLoop = EmbeddedEventLoop()
        var state = 0
        let p: EventLoopPromise<()> = EventLoopPromise(eventLoop: eventLoop, file: #file, line: #line)
        p.futureResult.map {
            XCTAssertEqual(state, 0)
            state += 1
        }.map {
            XCTAssertEqual(state, 1)
            state += 1
        }.whenSuccess {
            XCTAssertEqual(state, 2)
            state += 1
        }
        p.succeed(result: ())
        XCTAssertTrue(p.futureResult.isFulfilled)
        XCTAssertEqual(state, 3)
    }

    func testEventLoopHoppingInThen() throws {
        let n = 20
        let elg = MultiThreadedEventLoopGroup(numThreads: n)
        var prev: EventLoopFuture<Int> = elg.next().newSucceededFuture(result: 0)
        (1..<20).forEach { (i: Int) in
            let p: EventLoopPromise<Int> = elg.next().newPromise()
            prev.then { (i2: Int) -> EventLoopFuture<Int> in
                XCTAssertEqual(i - 1, i2)
                p.succeed(result: i)
                return p.futureResult
            }.whenSuccess { i2 in
                XCTAssertEqual(i, i2)
            }
            prev = p.futureResult
        }
        XCTAssertEqual(n-1, try prev.wait())
        XCTAssertNoThrow(try elg.syncShutdownGracefully())
    }

    func testEventLoopHoppingInThenWithFailures() throws {
        enum DummyError: Error {
            case dummy
        }
        let n = 20
        let elg = MultiThreadedEventLoopGroup(numThreads: n)
        var prev: EventLoopFuture<Int> = elg.next().newSucceededFuture(result: 0)
        (1..<n).forEach { (i: Int) in
            let p: EventLoopPromise<Int> = elg.next().newPromise()
            prev.then { (i2: Int) -> EventLoopFuture<Int> in
                XCTAssertEqual(i - 1, i2)
                if i == n/2 {
                    p.fail(error: DummyError.dummy)
                } else {
                    p.succeed(result: i)
                }
                return p.futureResult
            }.thenIfError { error in
                p.fail(error: error)
                return p.futureResult
            }.whenSuccess { i2 in
                XCTAssertEqual(i, i2)
            }
            prev = p.futureResult
        }
        do {
            _ = try prev.wait()
            XCTFail("should have failed")
        } catch _ as DummyError {
            // OK
        } catch {
            XCTFail("wrong error \(error)")
        }
        XCTAssertNoThrow(try elg.syncShutdownGracefully())
    }
    
    func testEventLoopHoppingAndAll() throws {
        let n = 20
        let elg = MultiThreadedEventLoopGroup(numThreads: n)
        let ps = (0..<n).map { (_: Int) -> EventLoopPromise<()> in
            elg.next().newPromise()
        }
        let allOfEm = EventLoopFuture<()>.andAll(ps.map { $0.futureResult }, eventLoop: elg.next())
        ps.reversed().forEach { p in
            DispatchQueue.global().async {
                p.succeed(result: ())
            }
        }
        try allOfEm.wait()
        XCTAssertNoThrow(try elg.syncShutdownGracefully())
    }
    
    func testEventLoopHoppingAndAllWithFailures() throws {
        enum DummyError: Error { case dummy }
        let n = 20
        let fireBackEl = MultiThreadedEventLoopGroup(numThreads: 1)
        let elg = MultiThreadedEventLoopGroup(numThreads: n)
        let ps = (0..<n).map { (_: Int) -> EventLoopPromise<()> in
            elg.next().newPromise()
        }
        let allOfEm = EventLoopFuture<()>.andAll(ps.map { $0.futureResult }, eventLoop: fireBackEl.next())
        ps.reversed().enumerated().forEach { idx, p in
            DispatchQueue.global().async {
                if idx == n / 2 {
                    p.fail(error: DummyError.dummy)
                } else {
                    p.succeed(result: ())
                }
            }
        }
        do {
            try allOfEm.wait()
            XCTFail("unexpected failure")
        } catch _ as DummyError {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        XCTAssertNoThrow(try elg.syncShutdownGracefully())
        XCTAssertNoThrow(try fireBackEl.syncShutdownGracefully())
    }
    
    func testFutureInVariousScenarios() throws {
        enum DummyError: Error { case dummy0; case dummy1 }
        let elg = MultiThreadedEventLoopGroup(numThreads: 2)
        let el1 = elg.next()
        let el2 = elg.next()
        precondition(el1 !== el2)
        let q1 = DispatchQueue(label: "q1")
        let q2 = DispatchQueue(label: "q2")
        
        // this determines which promise is fulfilled first (and (true, true) meaning they race)
        for whoGoesFirst in [(false, true), (true, false), (true, true)] {
            // this determines what EventLoops the Promises are created on
            for eventLoops in [(el1, el1), (el1, el2), (el2, el1), (el2, el2)] {
                // this determines if the promises fail or succeed
                for whoSucceeds in [(false, false), (false, true), (true, false), (true, true)] {
                    let p0: EventLoopPromise<Int> = eventLoops.0.newPromise()
                    let p1: EventLoopPromise<String> = eventLoops.1.newPromise()
                    let fAll = p0.futureResult.and(p1.futureResult)
                    
                    // preheat both queues so we have a better chance of racing
                    let sem1 = DispatchSemaphore(value: 0)
                    let sem2 = DispatchSemaphore(value: 0)
                    let g = DispatchGroup()
                    q1.async(group: g) {
                        sem2.signal()
                        sem1.wait()
                    }
                    q2.async(group: g) {
                        sem1.signal()
                        sem2.wait()
                    }
                    g.wait()
                    
                    if whoGoesFirst.0 {
                        q1.async {
                            if whoSucceeds.0 {
                                p0.succeed(result: 7)
                            } else {
                                p0.fail(error: DummyError.dummy0)
                            }
                            if !whoGoesFirst.1 {
                                q2.asyncAfter(deadline: .now() + 0.1) {
                                    if whoSucceeds.1 {
                                        p1.succeed(result: "hello")
                                    } else {
                                        p1.fail(error: DummyError.dummy1)
                                    }
                                }
                            }
                        }
                    }
                    if whoGoesFirst.1 {
                        q2.async {
                            if whoSucceeds.1 {
                                p1.succeed(result: "hello")
                            } else {
                                p1.fail(error: DummyError.dummy1)
                            }
                            if !whoGoesFirst.0 {
                                q1.asyncAfter(deadline: .now() + 0.1) {
                                    if whoSucceeds.0 {
                                        p0.succeed(result: 7)
                                    } else {
                                        p0.fail(error: DummyError.dummy0)
                                    }
                                }
                            }
                        }
                    }
                    do {
                        let result = try fAll.wait()
                        if !whoSucceeds.0 || !whoSucceeds.1 {
                            XCTFail("unexpected success")
                        } else {
                            XCTAssert((7, "hello") == result)
                        }
                    } catch let e as DummyError {
                        switch e {
                        case .dummy0:
                            XCTAssertFalse(whoSucceeds.0)
                        case .dummy1:
                            XCTAssertFalse(whoSucceeds.1)
                        }
                    } catch {
                        XCTFail("unexpected error: \(error)")
                    }
                }
            }
        }
        
        XCTAssertNoThrow(try elg.syncShutdownGracefully())
    }

    func testLoopHoppingHelperSuccess() throws {
        let group = MultiThreadedEventLoopGroup(numThreads: 2)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }
        let loop1 = group.next()
        let loop2 = group.next()
        XCTAssertFalse(loop1 === loop2)

        let succeedingPromise: EventLoopPromise<Void> = loop1.newPromise()
        let succeedingFuture = succeedingPromise.futureResult.map {
            XCTAssertTrue(loop1.inEventLoop)
        }.hopTo(eventLoop: loop2).map {
            XCTAssertTrue(loop2.inEventLoop)
        }
        succeedingPromise.succeed(result: ())
        XCTAssertNoThrow(try succeedingFuture.wait())
    }

    func testLoopHoppingHelperFailure() throws {
        let group = MultiThreadedEventLoopGroup(numThreads: 2)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }

        let loop1 = group.next()
        let loop2 = group.next()
        XCTAssertFalse(loop1 === loop2)

        let failingPromise: EventLoopPromise<Void> = loop2.newPromise()
        let failingFuture = failingPromise.futureResult.thenIfErrorThrowing { error in
            XCTAssertEqual(error as? EventLoopFutureTestError, EventLoopFutureTestError.example)
            XCTAssertTrue(loop2.inEventLoop)
            throw error
        }.hopTo(eventLoop: loop1).mapIfError { error in
            XCTAssertEqual(error as? EventLoopFutureTestError, EventLoopFutureTestError.example)
            XCTAssertTrue(loop1.inEventLoop)
        }

        failingPromise.fail(error: EventLoopFutureTestError.example)
        XCTAssertNoThrow(try failingFuture.wait())
    }

    func testLoopHoppingHelperNoHopping() throws {
        let group = MultiThreadedEventLoopGroup(numThreads: 2)
        defer {
            XCTAssertNoThrow(try group.syncShutdownGracefully())
        }
        let loop1 = group.next()
        let loop2 = group.next()
        XCTAssertFalse(loop1 === loop2)

        let noHoppingPromise: EventLoopPromise<Void> = loop1.newPromise()
        let noHoppingFuture = noHoppingPromise.futureResult.hopTo(eventLoop: loop1)
        XCTAssertTrue(noHoppingFuture === noHoppingPromise.futureResult)
        noHoppingPromise.succeed(result: ())
    }
}
