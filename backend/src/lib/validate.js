import { AppError } from '../errors.js';

/**
 * Validate one part of the request with a Zod schema.
 *
 * Usage:  router.post('/', validate({ body: registerSchema }), handler)
 *
 * The parsed value replaces the raw one, so downstream handlers get coerced
 * numbers and trimmed strings rather than whatever the client sent.
 */
export function validate(schemas) {
  return function validateMiddleware(req, _res, next) {
    for (const part of ['body', 'query', 'params']) {
      const schema = schemas[part];
      if (!schema) continue;

      const result = schema.safeParse(req[part]);
      if (!result.success) {
        const details = result.error.issues.map((issue) => ({
          field: [part, ...issue.path].join('.'),
          message: issue.message,
        }));
        return next(AppError.validation('Some fields need attention.', details));
      }
      // req.query has a getter in Express 5; assign defensively.
      try {
        req[part] = result.data;
      } catch {
        Object.defineProperty(req, part, { value: result.data, writable: true });
      }
    }
    return next();
  };
}

export default validate;
