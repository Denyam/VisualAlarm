import { tool } from "@opencode-ai/plugin"; // OpenCode plugin interface
import * as fs from "fs";
import * as path from "path";

// Only these source files get headers; everything else (configs, docs,
// gitignore, JSON, …) must stay untouched or the extra bytes break parsing.
const HEADER_EXTENSIONS = new Set([
  ".swift", // Swift
  ".h", ".m", ".mm", // Objective-C / Objective-C++
  ".c", ".cpp", ".cc", ".cxx", ".hpp", // C / C++
]);

function generateHeader(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  if (!HEADER_EXTENSIONS.has(ext)) {
    return "";
  }
  const dateStr = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const fileName = path.basename(filePath);
  return `/**\n * File: ${fileName}\n * Created: ${dateStr}\n */\n\n`;
}

export default tool({
  description: "Overwrite or create a file with custom headers injected automatically.",
  args: {
    filePath: tool.schema.string().describe("Relative path to the target file"),
    content: tool.schema.string().describe("Content to write into the file")
  },
  async execute(args, context) {
    const fullPath = path.resolve(context.directory, args.filePath);
    const fileExists = fs.existsSync(fullPath);

    let finalContent = args.content;

    // Only inject header if the file is new
    if (!fileExists) {
      const header = generateHeader(args.filePath);
      finalContent = `${header}${args.content}`;
    }

    // Ensure target directory structure exists
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    
    // Write contents to disk
    fs.writeFileSync(fullPath, finalContent, "utf-8");

    return `Successfully written file to ${args.filePath}`;
  }
});

