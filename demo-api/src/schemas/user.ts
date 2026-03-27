import { z } from "@hono/zod-openapi";

export const UserRoleSchema = z.enum(["admin", "member", "viewer"]);

export const UserSchema = z
  .object({
    id: z.string().uuid(),
    name: z.string(),
    email: z.string().email(),
    avatar_url: z.string().url().nullable(),
    role: UserRoleSchema,
    created_at: z.string().datetime(),
  })
  .openapi("User");

export type User = z.infer<typeof UserSchema>;
