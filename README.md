# Future

Lightweight implementations of `Future<T>`. Create a new future:

 *  `Future<T>(resolved _: T)`;
 *  `Future<T>(@autoclose(escaping) _: () -> T)`;
 *  `Future<T>.promise(cancel _: FutureCancel? = default) -> (Future<T>, resolve: T -> Bool)`;

or use a future:

 *  `observe(block: T -> ()) -> FutureCancel?`;
 *  `map<U>(transform: T -> U) -> Future<U>`;
 *  `flatMap<U>(transform: T -> Future<U>) -> Future<U>`.

where `typealias FutureCancel = () -> ()` is a cancel block, returned only if the future was not yet resolved. Calling the cancel block will deregister the observation.

The cancel block retains the future, and is called either manually or during a future’s deinitialization only if it’s still unresolved. Releasing the cancel block in turn releases the retained future.

Mapped futures indirectly retain their upstream future (under the hood, they use `observe` and retain the cancel block), releasing it upon resolution.

By default, the cancel block of the future at the beginning of the chain does nothing. A custom cancel block can be passed to the static `promise` method in order to cancel work that is done to resolve it, should that resolution and therefore the work itself become unnecessary. For example, a cancel block could cancel a network request.
