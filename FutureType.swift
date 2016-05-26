//
//  FutureType.swift
//  Future
//
//  Created by Bastiaan Marinus van de Weerd on 26/05/16.
//  Copyright © 2016 Bastiaan Marinus van de Weerd. All rights reserved.
//


public typealias FutureCancel = () -> ()


public enum FutureContext {
	case Immediate
	case Sync(dispatch_queue_t!)
	case Async(dispatch_queue_t!)
	case Main
	case Custom((() -> ()) -> ())

	var block: (() -> ()) -> () {
		switch self {
		case .Immediate: return { $0() }
		case .Sync(let queue): return { dispatch_sync(queue ?? dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), $0) }
		case .Async(let queue): return { dispatch_async(queue ?? dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), $0) }
		case .Main: return { pthread_main_np() != 0 ? $0() : dispatch_async(dispatch_get_main_queue(), $0) }
		case .Custom(let block): return block
		}
	}
}


public protocol FutureType {
	associatedtype Value

	init(resolved: Value)
	init(@autoclosure(escaping) _: () -> Value)

	func observe(context: FutureContext, block: Value -> ()) -> FutureCancel?
	
	func map<U>(context: FutureContext, transform: Value -> U) -> Future<U>
	func flatMap<U>(context: FutureContext, transform: Value -> Future<U>) -> Future<U>

	static func promise(cancel _: FutureCancel) -> (Self, resolve: Value -> Bool)
	static func promise() -> (Self, resolve: Value -> Bool)
}
