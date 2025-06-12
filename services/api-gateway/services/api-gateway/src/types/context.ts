import { Request } from 'express';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';

export interface User {
  id: string;
  email?: string;
  role?: string;
}

export interface Context {
  user?: User;
  req: Request;
  prisma: PrismaClient;
  redis: Redis;
}
