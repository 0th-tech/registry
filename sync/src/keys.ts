import { createRequire } from "node:module";
import type { Account } from "starknet";
import { z } from "zod";

// Node cannot load noir-jwt 0.4.5's ESM build, which uses extensionless imports
const { splitBigIntToChunks } = createRequire(import.meta.url)(
  "noir-jwt",
) as typeof import("noir-jwt");

const JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";

const jwk = z.object({
  kty: z.string(),
  alg: z.string().optional(),
  n: z.string().optional(),
  e: z.string().optional(),
});

function keyLimbs(key: z.infer<typeof jwk>) {
  if (key.kty !== "RSA" || !key.n) throw new Error("not an RSA public key");
  // The circuit only checks seals made with exponent 65537
  if (key.e !== "AQAB") throw new Error(`exponent is not 65537: e ${key.e}`);
  const modulus = BigInt(
    `0x${Buffer.from(key.n, "base64url").toString("hex")}`,
  );
  const bits = modulus.toString(2).length;
  // The circuit only checks seals made with a 2048-bit key
  if (bits !== 2048) throw new Error(`key is not 2048 bits: ${bits}`);
  // The circuit splits the modulus with this same noir-jwt function
  return splitBigIntToChunks(modulus, 120, 18).map(String);
}

// Google publishes its next key ahead of a rotation, so all its keys are registered
async function googleKeys() {
  const res = await fetch(JWKS_URL).catch((cause) => {
    throw new Error(`cannot reach ${JWKS_URL}`, { cause });
  });
  if (!res.ok) throw new Error(`${JWKS_URL} answered ${res.status}`);
  const { keys } = z.object({ keys: z.array(jwk) }).parse(await res.json());
  // The circuit only checks RS256 seals
  const signing = keys.filter((key) => key.alg === "RS256");
  if (!signing.length) throw new Error("Google publishes no RS256 key");
  return signing.map(keyLimbs);
}

// A u256 is sent as two felts, low then high, and a 120-bit limb fits in the low one
const keyCalldata = (limbs: string[]) => [
  String(limbs.length),
  ...limbs.flatMap((limb) => [limb, "0"]),
];

// A key Google stops publishing is never removed, it stops being valid after 30 days
export async function renewKeys(account: Account, registry: string) {
  const keys = await googleKeys();
  const { transaction_hash } = await account.execute(
    keys.map((limbs) => ({
      contractAddress: registry,
      entrypoint: "renew_key",
      calldata: keyCalldata(limbs),
    })),
  );
  await account.provider.waitForTransaction(transaction_hash);
  return keys;
}
