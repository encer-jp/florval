import { z } from "@hono/zod-openapi";
import { UserSchema } from "./user.js";

export const TaskStatusSchema = z.enum(["todo", "in_progress", "done"]);
export const TaskPrioritySchema = z.enum(["low", "medium", "high", "urgent"]);

export const TaskSchema = z
  .object({
    id: z.string().uuid(),
    title: z.string(),
    description: z.string().nullable(),
    status: TaskStatusSchema,
    priority: TaskPrioritySchema,
    assignee_id: z.string().uuid().nullable(),
    assignee: UserSchema.nullable(),
    tags: z.array(z.string()),
    due_date: z.string().datetime().nullable(),
    created_at: z.string().datetime(),
    updated_at: z.string().datetime(),
  })
  .openapi("Task");

export const CreateTaskRequestSchema = z
  .object({
    title: z.string().min(1),
    description: z.string().nullable().optional(),
    status: TaskStatusSchema.default("todo"),
    priority: TaskPrioritySchema.default("medium"),
    assignee_id: z.string().uuid().nullable().optional(),
    due_date: z.string().datetime().nullable().optional(),
    tags: z.array(z.string()).default([]),
  })
  .openapi("CreateTaskRequest");

export const UpdateTaskRequestSchema = z
  .object({
    title: z.string().min(1),
    description: z.string().nullable().optional(),
    status: TaskStatusSchema,
    priority: TaskPrioritySchema,
    assignee_id: z.string().uuid().nullable().optional(),
    due_date: z.string().datetime().nullable().optional(),
    tags: z.array(z.string()).default([]),
  })
  .openapi("UpdateTaskRequest");

export type Task = z.infer<typeof TaskSchema>;
