import { writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { stringify } from "yaml";
import app from "./app.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const outputPath = resolve(__dirname, "..", "openapi.yaml");

const doc = app.getOpenAPI31Document({
	openapi: "3.1.0",
	info: {
		title: "florval Demo API",
		version: "1.0.0",
		description:
			"Demo API server for florval - showcases all florval code generation features",
	},
});

const yamlContent = stringify(doc, { lineWidth: 120 });
writeFileSync(outputPath, yamlContent, "utf-8");
console.log(`OpenAPI spec written to ${outputPath}`);
