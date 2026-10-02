import config from '../config.js';

/**
 * Outbound transactional messages.
 *
 * There is no email or SMS provider wired up yet - it needs a provider
 * decision (see the Known gaps section of the README) - so this logs the
 * message instead of sending it. The point of keeping it behind a function is
 * that adding a provider is a change to this file only: the routes that call
 * `deliverPasswordReset` do not care how the message actually left the
 * building.
 *
 * A delivery failure must never fail the request that triggered it. The caller
 * has already created the reset token, and telling the member "sorry, try
 * again" when the token is perfectly valid would be worse than a log line.
 */

const RESET_SUBJECT = 'Reset your BoaMe password';

const RESET_BODY = (name, token) => `Hi ${name},

Someone asked to reset the password for your BoaMe account.

  ${config.appBaseUrl}/reset-password?token=${token}

This link works once and expires in one hour. If this was not you, ignore it -
your password has not changed and no action is needed.
`;

/**
 * Hand a password-reset token to its owner.
 *
 * @param {{ user: { id: string, name: string, email: string|null, phone: string }, token: string }} args
 */
export async function deliverPasswordReset({ user, token }) {
  const to = user.email || user.phone;
  const body = RESET_BODY(user.name, token);

  if (config.isProduction) {
    // TODO: replace with the chosen provider. Until this is implemented a
    // production deployment will log the token instead of sending it, which
    // means password reset does not work in production - fail loudly rather
    // than quietly doing nothing.
    console.error(
      `[mailer] no provider configured - password reset for ${to} was NOT sent`,
    );
    return;
  }

  console.info(
    [
      '',
      '──────── password reset ────────',
      `to:      ${to}`,
      `subject: ${RESET_SUBJECT}`,
      body.trim(),
      '────────────────────────────────',
      '',
    ].join('\n'),
  );
}

export default { deliverPasswordReset };
