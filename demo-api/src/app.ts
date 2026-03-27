import { OpenAPIHono } from "@hono/zod-openapi";
import { swaggerUI } from "@hono/swagger-ui";
import { cors } from "hono/cors";
import taskRoutes from "./routes/tasks.js";
import userRoutes from "./routes/users.js";
import projectRoutes from "./routes/projects.js";
import notificationRoutes from "./routes/notifications.js";
import uploadRoutes from "./routes/uploads.js";

const app = new OpenAPIHono();

// CORS for Flutter Web (localhost) access
app.use("/*", cors());

// Register routes
app.route("/", taskRoutes);
app.route("/", userRoutes);
app.route("/", projectRoutes);
app.route("/", notificationRoutes);
app.route("/", uploadRoutes);

// OpenAPI doc
app.doc31("/doc", {
  openapi: "3.1.0",
  info: {
    title: "florval Demo API",
    version: "1.0.0",
    description:
      "Demo API server for florval - showcases all florval code generation features",
  },
});

// Swagger UI
app.get("/ui", swaggerUI({ url: "/doc" }));

// Root redirect
app.get("/", (c) => c.redirect("/ui"));

// Zod validation error handler
app.onError((err, c) => {
  if (err.message.includes("Validation")) {
    return c.json(
      {
        message: "Validation error",
        errors: [{ field: "unknown", message: err.message }],
      },
      422
    );
  }
  return c.json(
    { message: "Internal server error", code: "INTERNAL_ERROR" },
    500
  );
});

export default app;
