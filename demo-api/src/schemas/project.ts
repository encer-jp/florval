import { z } from "@hono/zod-openapi";
import { UserSchema } from "./user.js";

export const ProjectSchema = z
  .object({
    id: z.string().uuid(),
    name: z.string(),
    description: z.string().nullable(),
    owner: UserSchema,
    members: z.array(UserSchema),
    task_count: z.number().int(),
    created_at: z.string().datetime(),
    updated_at: z.string().datetime(),
  })
  .openapi("Project");

export const CreateProjectRequestSchema = z
  .object({
    name: z.string().min(1),
    description: z.string().nullable().optional(),
    member_ids: z.array(z.string().uuid()),
  })
  .openapi("CreateProjectRequest");

export type Project = z.infer<typeof ProjectSchema>;
