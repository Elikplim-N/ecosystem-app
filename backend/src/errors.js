/**
 * Every error that should reach a client is an AppError. Anything else that
 * escapes a route is a bug and becomes a generic 500, so internal details
 * (SQL fragments, stack traces, connection strings) never leak.
 */
export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(message, details) {
    return new AppError(400, 'bad_request', message, details);
  }

  static validation(message, details) {
    return new AppError(422, 'validation_failed', message, details);
  }

  static unauthorized(message = 'Not signed in.') {
    return new AppError(401, 'unauthorized', message);
  }

  static invalidCredentials() {
    // Deliberately vague: saying "no such user" would confirm which phone
    // numbers are registered.
    return new AppError(401, 'invalid_credentials', 'Incorrect phone number or password.');
  }

  static forbidden(message = 'You do not have permission to do that.') {
    return new AppError(403, 'forbidden', message);
  }

  static notFound(what = 'Record') {
    return new AppError(404, 'not_found', `${what} not found.`);
  }

  static conflict(message, details) {
    return new AppError(409, 'conflict', message, details);
  }

  static locked(message = 'Too many attempts. Try again later.') {
    return new AppError(423, 'account_locked', message);
  }

  static internal(message = 'Something went wrong.') {
    return new AppError(500, 'internal_error', message);
  }
}
