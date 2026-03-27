import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { UserSchema } from "../schemas/user.js";
import {
  NotFoundErrorSchema,
} from "../schemas/error.js";
import { createCursorPaginatedSchema } from "../schemas/pagination.js";
import { users } from "../store/memory.js";

const app = new OpenAPIHono();

const CursorPaginatedUserSchema = createCursorPaginatedSchema(
  UserSchema,
  "CursorPaginatedUsers"
);

// GET /users
const listUsersRoute = createRoute({
  method: "get",
  path: "/users",
  tags: ["users"],
  operationId: "listUsers",
  request: {
    query: z.object({
      limit: z.coerce.number().int().min(1).max(100).default(5).optional(),
      search: z.string().optional(),
      after: z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: CursorPaginatedUserSchema } },
      description: "Cursor-paginated user list",
    },
  },
});

app.openapi(listUsersRoute, (c) => {
  const { limit = 5, search, after } = c.req.valid("query");

  let filtered = [...users];
  if (search) {
    const q = search.toLowerCase();
    filtered = filtered.filter((u) => u.name.toLowerCase().includes(q));
  }

  let startIndex = 0;
  if (after) {
    const idx = filtered.findIndex((u) => u.id === after);
    if (idx >= 0) startIndex = idx + 1;
  }

  const sliced = filtered.slice(startIndex, startIndex + limit);
  const hasMore = startIndex + limit < filtered.length;
  const nextCursor = hasMore ? sliced[sliced.length - 1]?.id ?? null : null;

  return c.json({ items: sliced, nextCursor, hasMore }, 200);
});

// GET /users/:id
const getUserRoute = createRoute({
  method: "get",
  path: "/users/{id}",
  tags: ["users"],
  operationId: "getUser",
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: UserSchema } },
      description: "User detail",
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
