/**
 * Wraps an async route handler so a rejected promise reaches Express's error
 * handler. Without this, `await` inside a handler that throws produces an
 * unhandled rejection and the request hangs until it times out.
 */
export function asyncHandler(fn) {
  return function wrapped(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

export default asyncHandler;
