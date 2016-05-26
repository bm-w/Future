//
//  Tests.swift
//  FutureTests
//
//  Created by Bastiaan Marinus van de Weerd on 26/05/16.
//  Copyright © 2016 Bastiaan Marinus van de Weerd. All rights reserved.
//


import XCTest
@testable import Future


class FuturesTests: XCTestCase {
    private func _assertPending(future: Future<Bool>) {
		switch future.state {
		case let .Pending(dispose, blocks):
			XCTAssertNil(dispose, "Expecting dispose function to be nil.")
			XCTAssert(blocks.isEmpty, "Expecting resolution blocks array to be empty.")
		case .Resolved:
			XCTFail("Expecting future to be pending.")
		}
    }

    func testPending() {
		self._assertPending(Future<Bool>())
    }

	private func _assertResolved(future: Future<Bool>) {
		switch future.state {
		case .Pending:
			XCTFail("Expecting future to be resolved.")
		case .Resolved(let value):
			XCTAssertTrue(value, "Expecting value to equal `true`.")
		}
	}

    func testResolved() {
		self._assertResolved(Future(resolved: true))
    }

    func testObservation() {
		var future: Future<Bool>? = Future<Bool>()
		weak var weakFuture = future

		var cancel = future?.observe() { value in
			XCTFail("Expecting this block not to run.")
		}

		XCTAssertNotNil(cancel, "Expecting cancel block to be non-nil.")

		future = nil

		switch weakFuture?.state {
		case nil:
			XCTFail("Expecting future to still exist.")
		case let .Some(.Pending(cancel, blocks)):
			XCTAssertNil(cancel, "Expecting cancel block to be nil.")
			XCTAssert(blocks.count == 1, "Expecting resolution blocks array to contain one element.")
		case .Some(.Resolved):
			XCTFail("Expecting future to be pending.")
		}

		cancel = nil
		XCTAssertNil(weakFuture, "Expecting future to have been released.")
    }

    func testPromise() {
		let (future, resolve) = Future<Bool>.promise()
		self._assertPending(future)

		resolve(true)
		self._assertResolved(future)
	}

    func testAutoclosure() {
		let sleepExpectation = self.expectationWithDescription("Sleep time has passed.")
		func block() -> Bool {
			usleep(1000)
			sleepExpectation.fulfill()
			return true
		}

		let future = Future(block())

		let resolutionExpectation = self.expectationWithDescription("Future is resolved.")
		var cancel = future.observe(.Main) { value in
			resolutionExpectation.fulfill()
		}

		XCTAssertNotNil(cancel, "Expecting cancel block to be non-nil.")

		self.waitForExpectationsWithTimeout(1.1) { error in
			XCTAssertNil(error, error?.localizedFailureReason ?? "?")
			self._assertResolved(future)
			cancel = nil
		}
	}
}
