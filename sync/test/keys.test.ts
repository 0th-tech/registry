import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { keyCalldata, keyLimbs } from "../src/keys.ts";

// The key that signs the letter of the circuit's release, with the limbs its proof makes public
const fixture: {
  jwk: { kty: string; n: string; e: string };
  pubkey_modulus_limbs: string[];
} = JSON.parse(
  readFileSync(
    new URL("../target/circuit/fixture.json", import.meta.url),
    "utf8",
  ),
);

test("keyLimbs gives the limbs the circuit makes public", () => {
  assert.deepEqual(keyLimbs(fixture.jwk), fixture.pubkey_modulus_limbs);
});

test("keyLimbs refuses a key the circuit cannot check", () => {
  const half = Buffer.from(fixture.jwk.n, "base64url").subarray(0, 128);

  assert.throws(() => keyLimbs({ ...fixture.jwk, kty: "EC" }), {
    message: "not an RSA public key",
  });
  assert.throws(() => keyLimbs({ ...fixture.jwk, e: "Aw" }), {
    message: "exponent is not 65537: e Aw",
  });
  assert.throws(
    () => keyLimbs({ ...fixture.jwk, n: half.toString("base64url") }),
    { message: "key is not 2048 bits: 1024" },
  );
});

test("keyCalldata sends the limb count, then each limb as a u256", () => {
  assert.deepEqual(keyCalldata(["7", "8"]), ["2", "7", "0", "8", "0"]);
});
