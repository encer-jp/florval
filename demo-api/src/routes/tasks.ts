import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import {
  TaskSchema,
  TaskStatusSchema,
  TaskPrioritySchema,
  CreateTaskRequestSchema,
  UpdateTaskRequestSchema,
} from "../schemas/task.js";
import {
  UnauthorizedErrorSchema,
  NotFoundErrorSchema,
  ValidationErrorSchema,
  ServerErrorSchema,
} from "../schemas/error.js";
import { authMiddleware } from "../middleware/auth.js";
import { tasks } from "../store/memory.js";
import { users } from "../store/memory.js";

const app = new OpenAPIHono();
app.use("/tasks/*", authMiddleware);
app.use("/tasks", authMiddleware);

// GET /tasks
const listTasksRoute = createRoute({
  method: "get",
  path: "/tasks",
  tags: ["tasks"],
  operationId: "listTasks",
  security: [{ Bearer: [] }],
  request: {
    query: z.object({
      status: TaskStatusSchema.optional(),
      priority: TaskPrioritySchema.optional(),
      assignee_id: z.string().uuid().optional(),
      trigger_error: z.string().optional(),
    }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: z.array(TaskSchema) } },
      description: "Task list",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    500: {
      content: { "application/json": { schema: ServerErrorSchema } },
      description: "Server error",
    },
  },
});

app.openapi(listTasksRoute, (c) => {
  const { status, priority, assignee_id, trigger_error } =
    c.req.valid("query");

  if (trigger_error === "true") {
    return c.json(
      { message: "Internal server error", code: "INTERNAL_ERROR" },
      500
    );
  }

  let result = [...tasks];
  if (status) result = result.filter((t) => t.status === status);
  if (priority) result = result.filter((t) => t.priority === priority);
  if (assignee_id)
    result = result.filter((t) => t.assignee_id === assignee_id);

  return c.json(result, 200);
});

// GET /tasks/:id
const getTaskRoute = createRoute({
  method: "get",
  path: "/tasks/{id}",
  tags: ["tasks"],
  operationId: "getTask",
  security: [{ Bearer: [] }],
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: TaskSchema } },
      description: "Task detail",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    404: {
      content: { "application/json": { schema: NotFoundErrorSchema } },
      description: "Task not found",
    },
  },
});

app.openapi(getTaskRoute, (c) => {
  const { id } = c.req.valid("param");
  const task = tasks.find((t) => t.id === id);
  if (!task) return c.json({ message: "Task not found" }, 404);
  return c.json(task, 200);
});

// POST /tasks
const createTaskRoute = createRoute({
  method: "post",
  path: "/tasks",
  tags: ["tasks"],
  operationId: "createTask",
  security: [{ Bearer: [] }],
  request: {
    body: {
      content: { "application/json": { schema: CreateTaskRequestSchema } },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: TaskSchema } },
      description: "Task created",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    422: {
      content: { "application/json": { schema: ValidationErrorSchema } },
      description: "Validation error",
    },
  },
});

app.openapi(createTaskRoute, (c) => {
  const body = c.req.valid("json");
  const now = new Date().toISOString();
  const assignee = body.assignee_id
    ? users.find((u) => u.id === body.assignee_id) ?? null
    : null;

  const task = {
    id: crypto.randomUUID(),
    title: body.title,
    description: body.description ?? null,
    status: body.status ?? ("todo" as const),
    priority: body.priority ?? ("medium" as const),
    assignee_id: body.assignee_id ?? null,
    assignee,
    tags: body.tags ?? [],
    due_date: body.due_date ?? null,
    created_at: now,
    updated_at: now,
  };

  tasks.push(task);
  return c.json(task, 201);
});

// PUT /tasks/:id
const updateTaskRoute = createRoute({
  method: "put",
  path: "/tasks/{id}",
  tags: ["tasks"],
  operationId: "updateTask",
  security: [{ Bearer: [] }],
  request: {
    params: z.object({ id: z.string().uuid() }),
    body: {
      content: { "application/json": { schema: UpdateTaskRequestSchema } },
      required: true,
    },
  },
  responses: {
    200: {
      content: { "application/json": { schema: TaskSchema } },
      description: "Task updated",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    404: {
      content: { "application/json": { schema: NotFoundErrorSchema } },
      description: "Task not found",
    },
    422: {
      content: { "application/json": { schema: ValidationErrorSchema } },
      description: "Validation error",
    },
  },
});

app.openapi(updateTaskRoute, (c) => {
  const { id } = c.req.valid("param");
  const body = c.req.valid("json");
  const index = tasks.findIndex((t) => t.id === id);
  if (index === -1) return c.json({ message: "Task not found" }, 404);

  const assignee = body.assignee_id
    ? users.find((u) => u.id === body.assignee_id) ?? null
    : null;

  const updated = {
    ...tasks[index],
    title: body.title,
    description: body.description ?? tasks[index].description,
    status: body.status,
    priority: body.priority,
    assignee_id: body.assignee_id ?? tasks[index].assignee_id,
    assignee,
    tags: body.tags ?? tasks[index].tags,
    due_date: body.due_date ?? tasks[index].due_date,
    updated_at: new Date().toISOString(),
  };

  tasks[index] = updated;
  return c.json(updated, 200);
});

// DELETE /tasks/:id
const deleteTaskRoute = createRoute({
  method: "delete",
  path: "/tasks/{id}",
  tags: ["tasks"],
  operationId: "deleteTask",
  security: [{ Bearer: [] }],
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    204: {
      description: "Task deleted",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    404: {
      content: { "application/json": { schema: NotFoundErrorSchema } },
      description: "Task not found",
    },
  },
});

app.openapi(deleteTaskRoute, (c) => {
  const { id } = c.req.valid("param");
  const index = tasks.findIndex((t) => t.id === id);
  if (index === -1) return c.json({ message: "Task not found" }, 404);
  tasks.splice(index, 1);
  return c.body(null, 204);
});

export default app;
