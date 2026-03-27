import { serve } from "@hono/node-server";
import app from "./app.js";

const port = 3000;
console.log(`florval Demo API running at http://localhost:${port}`);
console.log(`Swagger UI: http://localhost:${port}/ui`);
console.log(`OpenAPI spec: http://localhost:${port}/doc`);

serve({ fetch: app.fetch, port });
