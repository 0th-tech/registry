import { Account, RpcProvider, logger } from "starknet";
import { z } from "zod";
import { renewKeys } from "./keys.ts";

logger.setLogLevel("ERROR");

// Google's JWKS carries no expiry, so a key stays valid by being renewed hourly
const EVERY_MS = 60 * 60 * 1000;

const felt = z.string().regex(/^0x[0-9a-f]{1,64}$/i);

const parsed = z
  .object({
    RPC_URL: z.url(),
    REGISTRY: felt,
    REGISTRY_ADMIN_ACCOUNT: felt,
    REGISTRY_ADMIN_PRIVATE_KEY: felt,
  })
  .safeParse(process.env);
if (!parsed.success) throw new Error(z.prettifyError(parsed.error));
const env = parsed.data;

const account = new Account({
  provider: new RpcProvider({ nodeUrl: env.RPC_URL }),
  address: env.REGISTRY_ADMIN_ACCOUNT,
  signer: env.REGISTRY_ADMIN_PRIVATE_KEY,
});
const registry = env.REGISTRY;

const pass = async () => {
  try {
    const keys = await renewKeys(account, registry);
    console.log(`${new Date().toISOString()} ${keys.length} key(s) renewed`);
  } catch (error) {
    console.error(`${new Date().toISOString()} ${error}`);
  }
};

await pass();
setInterval(pass, EVERY_MS);
