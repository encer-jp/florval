import { z } from "@hono/zod-openapi";

export const ValidationErrorSchema = z
  .object({
    message: z.string(),
    errors: z.array(
      z.object({
        field: z.string(),
        message: z.string(),
      })
    ),
  })
  .openapi("ValidationError");

export const ServerErrorSchema = z
  .object({
    message: z.string(),
    code: z.string(),
  })
  .openapi("ServerError");

export const UnauthorizedErrorSchema = z
  .object({
    message: z.string(),
  })
  .openapi("UnauthorizedError");

export const NotFoundErrorSchema = z
  .object({
    message: z.string(),
  })
  .openapi("NotFoundError");
