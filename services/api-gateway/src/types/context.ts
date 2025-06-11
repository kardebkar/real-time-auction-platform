import { PrismaClient } from '@prisma/client';

export interface Context {
  user?: {
    id: string;
  };
  req?: any; // Using any to avoid Express type conflicts
  prisma: PrismaClient;
}