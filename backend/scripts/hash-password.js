/**
 * Generate an argon2id hash for a password, or set one on a user.
 *
 *   node scripts/hash-password.js                 # prompts, prints a hash
 *   node scripts/hash-password.js 'my-password'   # non-interactive
 *
 * The hash is safe to paste into a SQL update. The password is not.
 */
import readline from 'node:readline';
import argon2 from 'argon2';
import { hashPassword } from '../src/services/authService.js';

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

function ask(question, { silent = false } = {}) {
  return new Promise((resolve) => {
    if (!silent) {
      const q = readline.createInterface({ input: process.stdin, output: process.stdout });
      q.question(question, (answer) => {
        q.close();
        resolve(answer.trim());
      });
      return;
    }

    // Suppress echo.
    const onData = (char) => {
      if (['\n', '\r', ''].includes(String(char))) {
        process.stdin.removeListener('data', onData);
      } else {
        readline.clearLine(process.stdout, 0);
        readline.cursorTo(process.stdout, 0);
        process.stdout.write(question);
      }
    };
    process.stdin.on('data', onData);
    rl.question(question, (answer) => {
      process.stdout.write('\n');
      resolve(answer.trim());
    });
  });
}

const arg = process.argv[2];
const plain = arg ?? (await ask('Password: ', { silent: true }));
const confirm = arg ?? (await ask('Confirm:  ', { silent: true }));

if (!plain) {
  console.error('No password given.');
  process.exit(1);
}

if (!arg && plain !== confirm) {
  console.error('Passwords did not match.');
  process.exit(1);
}

if (plain.length < 8) {
  console.error('Use at least 8 characters.');
  process.exit(1);
}

const hash = await hashPassword(plain);

// Prove it round-trips before printing, so nobody pastes a broken hash.
const ok = await argon2.verify(hash, plain);
if (!ok) {
  console.error('Hash did not verify against its own password. Aborting.');
  process.exit(1);
}

console.log('\nHash (safe to store):\n');
console.log(hash);
console.log('\nSQL to apply it:\n');
console.log(`update users set password_hash = '${hash}' where phone = '+233...';`);
console.log('');

rl.close();
process.exit(0);
