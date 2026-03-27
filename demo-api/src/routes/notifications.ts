import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { NotificationSchema } from "../schemas/notification.js";
import { notifications } from "../store/memory.js";

const app = new OpenAPIHono();

const listNotificationsRoute = createRoute({
  method: "get",
  path: "/notifications",
  tags: ["notifications"],
  operationId: "listNotifications",
  responses: {
    200: {
      content: { "application/json": { schema: z.array(NotificationSchema) } },
      description: "Notification list",
    },
  },
});

app.openapi(listNotificationsRoute, (c) => {
  return c.json(notifications, 200);
});

export default app;
