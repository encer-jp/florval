import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { UserSchema } from "../schemas/user.js";
import {
  UnauthorizedErrorSchema,
  NotFoundErrorSchema,
} from "../schemas/error.js";
import { createPaginatedSchema } from "../schemas/pagination.js";
import { authMiddleware } from "../middleware/auth.js";
import { users } from "../store/memory.js";

const app = new OpenAPIHono();
app.use("/users/*", authMiddleware);
app.use("/users", authMiddleware);

const PaginatedUserSchema = createPaginatedSchema(UserSchema, "PaginatedUsers");

// GET /users
const listUsersRoute = createRoute({
  method: "get",
  path: "/users",
  tags: ["users"],
  operationId: "listUsers",
  security: [{ Bearer: [] }],
  request: {
    query: z.object({
      page: z.coerce.number().int().min(1).default(1).optional(),
      limit: z.coerce.number().int().min(1).max(100).default(20).optional(),
      search: z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: PaginatedUserSchema } },
      description: "Paginated user list",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
  },
});

app.openapi(listUsersRoute, (c) => {
  const { page = 1, limit = 20, search } = c.req.valid("query");

  let filtered = [...users];
  if (search) {
    const q = search.toLowerCase();
    filtered = filtered.filter((u) => u.name.toLowerCase().includes(q));
  }

  const total = filtered.length;
  const totalPages = Math.ceil(total / limit);
  const start = (page - 1) * limit;
  const data = filtered.slice(start, start + limit);

  return c.json({ data, page, limit, total, total_pages: totalPages }, 200);
});

// GET /users/:id
const getUserRoute = createRoute({
  method: "get",
  path: "/users/{id}",
  tags: ["users"],
  operationId: "getUser",
  security: [{ Bearer: [] }],
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: UserSchema } },
      description: "User detail",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    404: {
      content: { "application/json": { schema: NotFoundErrorSchema } },
      description: "User not found",
    },
  },
});

app.openapi(getUserRoute, (c) => {
  const { id } = c.req.valid("param");
  const user = users.find((u) => u.id === id);
  if (!user) return c.json({ message: "User not found" }, 404);
  return c.json(user, 200);
});

export default app;
