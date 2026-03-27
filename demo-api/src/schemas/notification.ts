import { z } from "@hono/zod-openapi";

export const TaskAssignedPayloadSchema = z
  .object({
    type: z.literal("task_assigned"),
    task_id: z.string().uuid(),
    task_title: z.string(),
    assigned_by: z.string(),
  })
  .openapi("TaskAssignedPayload");

export const CommentAddedPayloadSchema = z
  .object({
    type: z.literal("comment_added"),
    task_id: z.string().uuid(),
    task_title: z.string(),
    comment_text: z.string(),
    commented_by: z.string(),
  })
  .openapi("CommentAddedPayload");

export const ProjectInvitedPayloadSchema = z
  .object({
    type: z.literal("project_invited"),
    project_id: z.string().uuid(),
    project_name: z.string(),
    invited_by: z.string(),
  })
  .openapi("ProjectInvitedPayload");

export const NotificationPayloadSchema = z
  .discriminatedUnion("type", [
    TaskAssignedPayloadSchema,
    CommentAddedPayloadSchema,
    ProjectInvitedPayloadSchema,
  ])
  .openapi("NotificationPayload", {
    oneOf: [
      { $ref: "#/components/schemas/TaskAssignedPayload" },
      { $ref: "#/components/schemas/CommentAddedPayload" },
      { $ref: "#/components/schemas/ProjectInvitedPayload" },
    ],
    discriminator: {
      propertyName: "type",
      mapping: {
        task_assigned: "#/components/schemas/TaskAssignedPayload",
        comment_added: "#/components/schemas/CommentAddedPayload",
        project_invited: "#/components/schemas/ProjectInvitedPayload",
      },
    },
  });

export const NotificationSchema = z
  .object({
    id: z.string().uuid(),
    type: z.enum(["task_assigned", "comment_added", "project_invited"]),
    payload: NotificationPayloadSchema,
    created_at: z.string().datetime(),
    is_read: z.boolean(),
  })
  .openapi("Notification");

export type Notification = z.infer<typeof NotificationSchema>;
