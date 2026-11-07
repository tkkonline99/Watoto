import test from "node:test";
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const functionsDir = resolve(dirname(fileURLToPath(import.meta.url)), "../functions");

test("Cloud Functions unit test suite (payments, StoreKit sandbox, JWS x5c chain, GDPR constants)", () => {
  execFileSync("npm", ["test"], {
    cwd: functionsDir,
    stdio: "inherit",
  });
});
