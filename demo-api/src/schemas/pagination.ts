import { z, type ZodType } from "@hono/zod-openapi";

export function createPaginatedSchema<T extends ZodType>(
  itemSchema: T,
  name: string
) {
  return z
    .object({
      data: z.array(itemSchema),
      page: z.number().int(),
      limit: z.number().int(),
      total: z.number().int(),
      total_pages: z.number().int(),
    })
    .openapi(name);
}
