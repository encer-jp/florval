import { createMiddleware } from "hono/factory";
import { users } from "../store/memory.js";

const VALID_TOKEN = `demo-token-${users[0].id}`;

export const authMiddleware = createMiddleware(async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return c.json({ message: "Authorization header required" }, 401);
  }

  const token = authHeader.slice(7);
  if (token !== VALID_TOKEN) {
    return c.json({ message: "Invalid token" }, 401);
  }

  await next();
});
