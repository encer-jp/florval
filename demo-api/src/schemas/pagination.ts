import { z, type ZodType } from "@hono/zod-openapi";

export function createCursorPaginatedSchema<T extends ZodType>(
  itemSchema: T,
  name: string
) {
  return z
    .object({
      items: z.array(itemSchema),
      nextCursor: z.string().nullable(),
      hasMore: z.boolean(),
    })
    .openapi(name);
}
