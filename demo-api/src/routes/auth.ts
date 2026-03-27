import { createRoute, OpenAPIHono } from "@hono/zod-openapi";
import { LoginRequestSchema, LoginResponseSchema } from "../schemas/auth.js";
import { UnauthorizedErrorSchema } from "../schemas/error.js";
import { users } from "../store/memory.js";

const app = new OpenAPIHono();

const loginRoute = createRoute({
  method: "post",
  path: "/auth/login",
  tags: ["auth"],
  operationId: "login",
  request: {
    body: {
      content: { "application/json": { schema: LoginRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: LoginResponseSchema } },
      description: "Login successful",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Invalid credentials",
    },
  },
});

app.openapi(loginRoute, (c) => {
  const { email, password } = c.req.valid("json");

  if (email === "demo@example.com" && password === "password") {
    const user = users[0];
    return c.json(
      { token: `demo-token-${user.id}`, user },
      200
    );
  }

  return c.json({ message: "Invalid credentials" }, 401);
});

export default app;
