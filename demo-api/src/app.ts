import { OpenAPIHono } from "@hono/zod-openapi";

export function createApp() {
  const app = new OpenAPIHono();
  return app;
}
