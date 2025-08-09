import { PrismaClient } from "../generated/prisma";

// Create a single instance of Prisma Client to be reused across the application
export const prisma = new PrismaClient();

// Handle graceful shutdown
process.on("beforeExit", async () => {
  await prisma.$disconnect();
});
