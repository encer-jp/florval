import { z } from "@hono/zod-openapi";
import { UserSchema } from "./user.js";

export const LoginRequestSchema = z
  .object({
    email: z.string().email(),
    password: z.string(),
  })
  .openapi("LoginRequest");

export const LoginResponseSchema = z
  .object({
    token: z.string(),
    user: UserSchema,
  })
  .openapi("LoginResponse");
