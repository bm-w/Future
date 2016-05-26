//
//  Future.swift
//  Future
//
//  Created by Bastiaan Marinus van de Weerd on 26/05/16.
//  Copyright © 2016 Bastiaan Marinus van de Weerd. All rights reserved.
//


enum FutureState<T> {
	typealias Cancel = FutureCancel
	typealias Resolve = T -> ()

	case Pending(Cancel?, [Resolve?])
	case Resolved(T)
}


public final class Future<T>: FutureType {
	public typealias Context = FutureContext
	public typealias Value = T

	private var _lock = pthread_mutex_t()
	var state: FutureState<T>


	private init(state: FutureState<T>) {
		self.state = state
		let status = pthread_mutex_init(&self._lock, nil)
		assert(status == 0)
	}

	public convenience init(resolved value: T) {
		self.init(state: .Resolved(value))
	}

	convenience init(cancel: FutureState<T>.Cancel?) {
		self.init(state: .Pending(cancel, []))
	}

	convenience init() {
		self.init(cancel: nil)
	}

	public convenience init(@autoclosure(escaping) _ block: () -> T) {
		self.init()

		let queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
		dispatch_async(queue) { [weak self] in
			let value = block()

			dispatch_async(queue) { [weak self] in
				self?.resolve(value)
			}
		}
	}

	deinit {
		self._perform() {
			guard case .Pending(.Some(let cancel), _) = self.state else { return }
			cancel()
		}
		let status = pthread_mutex_destroy(&self._lock)
		assert(status == 0)
	}


	private func _perform<U>(@noescape block: () -> U) -> U {
		pthread_mutex_lock(&self._lock)
		let u = block()
		pthread_mutex_unlock(&self._lock)
		return u
	}

	private func _perform(@noescape block: () -> ()) {
		let _: ()! = self._perform({ block(); return () })
	}


	func resolve(value: T) {
		self._perform() {
			guard case .Pending(_, let blocks) = self.state else {
				assertionFailure()
				return
			}

			for block in blocks {
				block?(value)
			}

			self.state = .Resolved(value)
		}
	}


	public func observe(context: Context = .Immediate, block: T -> ()) -> FutureCancel? {
		let contextBlock: T -> () = { value in
			context.block({
				block(value)
			})
		}

		return self._perform() {
			switch self.state {
			case let .Pending(cancel, blocks):
				let index = blocks.endIndex
				self.state = .Pending(cancel, blocks + [.Some(contextBlock)])

				return {
					self._perform() {
						guard case .Pending(let cancel, var blocks) = self.state else {
							return
						}

						blocks[index] = nil
						self.state = .Pending(cancel, blocks)
					}
				}

			case .Resolved(let value):
				contextBlock(value)
				return nil
			}
		}
	}


	public func map<U>(context: Context = .Immediate, transform: T -> U) -> Future<U> {
		let mapped = Future<U>()

		let cancel = self.observe(context) { [weak mapped] value in
			assert(mapped != nil)
			mapped?.resolve(transform(value))
		}

		mapped._perform() {
			guard case .Pending(nil, let blocks) = mapped.state else {
				return
			}

			mapped.state = .Pending(cancel, blocks)
		}

		return mapped
	}

	public func flatMap<U>(context: Context = .Immediate, transform: T -> Future<U>) -> Future<U> {
		return self.map(context, transform: transform).flatten()
	}


	private static func _promise(cancel: FutureCancel?) -> (Future<T>, resolve: T -> Bool) {
		let future = self.init(cancel: cancel)

		let resolve = { [weak future] value in
			guard let strongFuture = future else {
				return false
			}

			strongFuture.resolve(value)
			return true
		} as (value: T) -> Bool

		return (future, resolve)
	}

	public static func promise(cancel cancel: FutureCancel) -> (Future<T>, resolve: T -> Bool) {
		return self._promise(cancel)
	}

	public static func promise() -> (Future<T>, resolve: T -> Bool) {
		return self._promise(nil)
	}
}


public extension FutureType where Value: FutureType {
	public func flatten() -> Future<Value.Value> {
		let flattened = Future<Value.Value>()

		let cancel = self.observe(.Immediate) { [weak flattened] futureValue in
			guard let flattened = flattened else {
				assertionFailure()
				return
			}

			let cancel = futureValue.observe(.Immediate) { [weak flattened] value in
				flattened?.resolve(value)
			}

			flattened._perform() {
				guard case let .Pending(.Some(originalCancel), blocks) = flattened.state else {
					return
				}

				flattened.state = .Pending({
					originalCancel()
					cancel?()
				}, blocks)
			}
		}

		flattened._perform() {
			guard case .Pending(nil, let blocks) = flattened.state else {
				return
			}

			flattened.state = .Pending(cancel, blocks)
		}

		return flattened
	}
}
