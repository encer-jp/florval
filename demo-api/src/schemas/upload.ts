import { z } from "@hono/zod-openapi";

export const UploadResultSchema = z
  .object({
    id: z.string().uuid(),
    filename: z.string(),
    size: z.number().int(),
    content_type: z.string(),
    url: z.string().url(),
    uploaded_at: z.string().datetime(),
  })
  .openapi("UploadResult");
