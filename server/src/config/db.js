const { PrismaClient } = require("@prisma/client");

// Single shared Prisma client instance across the app.
const prisma = new PrismaClient();

module.exports = { prisma };
