import { createRoute, OpenAPIHono, z } from "@hono/zod-openapi";
import { ProjectSchema, CreateProjectRequestSchema } from "../schemas/project.js";
import {
  UnauthorizedErrorSchema,
  NotFoundErrorSchema,
  ValidationErrorSchema,
} from "../schemas/error.js";
import { authMiddleware } from "../middleware/auth.js";
import { projects, users } from "../store/memory.js";

const app = new OpenAPIHono();
app.use("/projects/*", authMiddleware);
app.use("/projects", authMiddleware);

// GET /projects
const listProjectsRoute = createRoute({
  method: "get",
  path: "/projects",
  tags: ["projects"],
  operationId: "listProjects",
  security: [{ Bearer: [] }],
  responses: {
    200: {
      content: { "application/json": { schema: z.array(ProjectSchema) } },
      description: "Project list",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
  },
});

app.openapi(listProjectsRoute, (c) => {
  return c.json(projects, 200);
});

// GET /projects/:id
const getProjectRoute = createRoute({
  method: "get",
  path: "/projects/{id}",
  tags: ["projects"],
  operationId: "getProject",
  security: [{ Bearer: [] }],
  request: {
    params: z.object({ id: z.string().uuid() }),
  },
  responses: {
    200: {
      content: { "application/json": { schema: ProjectSchema } },
      description: "Project detail with owner and members",
    },
    401: {
      content: { "application/json": { schema: UnauthorizedErrorSchema } },
      description: "Unauthorized",
    },
    404: {
      content: { "application/json": { schema: NotFoundErrorSchema } },
      description: "Project not found",
    },
  },
});

app.openapi(getProjectRoute, (c) => {
  const { id } = c.req.valid("param");
  const project = projects.find((p) => p.id === id);
  if (!project) return c.json({ message: "Project not found" }, 404);
  return c.json(project, 200);
});

// POST /projects
const createProjectRoute = createRoute({
  method: "post",
  path: "/projects",
  tags: ["projects"],
  operationId: "createProject",
  security: [{ Bearer: [] }],
  request: {
    body: {
      content: { "application/json": { schema: CreateProjectRequestSchema } },
      required: true,
    },
  },
  responses: {
    201: {
      content: { "application/json": { schema: ProjectSchema } },
      description: "Project created",
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

app.openapi(createProjectRoute, (c) => {
  const body = c.req.valid("json");
  const now = new Date().toISOString();
  const owner = users[0]; // demo user is always the owner
  const members = body.member_ids
    .map((id) => users.find((u) => u.id === id))
    .filter((u): u is NonNullable<typeof u> => u != null);

  const project = {
    id: crypto.randomUUID(),
    name: body.name,
    description: body.description ?? null,
    owner,
    members,
    task_count: 0,
    created_at: now,
    updated_at: now,
  };

  projects.push(project);
  return c.json(project, 201);
});

export default app;
