import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { UploadResultSchema } from "../schemas/upload.js";
import { UnauthorizedErrorSchema } from "../schemas/error.js";
import { authMiddleware } from "../middleware/auth.js";

const app = new OpenAPIHono();
app.use("/uploads", authMiddleware);

const uploadRoute = createRoute({
  method: "post",
  path: "/uploads",
  tags: ["uploads"],
  operationId: "uploadFile",
  security: [{ Bearer: [] }],
  request: {
    body: {
      content: {
        "multipart/form-data": {
          schema: z.object({
            file: z.instanceof(File).openapi({ type: "string", format: "binary" }),
            description: z.string().optional(),
          }),
        },
      },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: UploadResultSchema } },
      description: "File uploaded",
    },
    400: {
      content: {
        "application/json": {
          schema: z.object({ message: z.string() }).openapi("BadRequestError"),
        },
      },
      description: "No file provided",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
  },
});

app.openapi(uploadRoute, async (c) => {
  const body = await c.req.parseBody();
  const file = body["file"];

  if (!file || !(file instanceof File)) {
    return c.json({ message: "No file provided" }, 400);
  }

  const result = {
    id: crypto.randomUUID(),
    filename: file.name,
    size: file.size,
    content_type: file.type || "application/octet-stream",
    url: `https://example.com/uploads/${crypto.randomUUID()}/${file.name}`,
    uploaded_at: new Date().toISOString(),
  };

  return c.json(result, 201);
});

export default app;
