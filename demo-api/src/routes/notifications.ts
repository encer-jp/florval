import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { NotificationSchema } from "../schemas/notification.js";
import { UnauthorizedErrorSchema } from "../schemas/error.js";
import { authMiddleware } from "../middleware/auth.js";
import { notifications } from "../store/memory.js";

const app = new OpenAPIHono();
app.use("/notifications", authMiddleware);

const listNotificationsRoute = createRoute({
  method: "get",
  path: "/notifications",
  tags: ["notifications"],
  operationId: "listNotifications",
  security: [{ Bearer: [] }],
  responses: {
    200: {
      content: { "application/json": { schema: z.array(NotificationSchema) } },
      description: "Notification list",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
  },
});

app.openapi(listNotificationsRoute, (c) => {
  return c.json(notifications, 200);
});

export default app;
