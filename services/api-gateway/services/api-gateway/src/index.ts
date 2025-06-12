import express from 'express';
import { ApolloServer } from 'apollo-server-express';
import { createServer } from 'http';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';
import { typeDefs } from './schema/typeDefs';
import { resolvers } from './resolvers';
import { Context } from './types/context';

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

async function startServer() {
  const app = express();

  app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
  }));
  app.use(express.json({ limit: '10mb' }));

  const server = new ApolloServer({
    typeDefs,
    resolvers,
    context: ({ req }): Context => {
      const token = req.headers.authorization?.replace('Bearer ', '');
      let user = undefined;

      if (token) {
        try {
          const payload: any = jwt.verify(token, process.env.JWT_SECRET || 'secret');
          user = { id: payload.userId };
        } catch (err: any) {
          console.warn('Invalid token:', err.message);
        }
      }

      return { user, req, prisma, redis };
    },
    introspection: true,
    formatError: (error) => {
      console.error('GraphQL Error:', error);
      return {
        message: error.message,
        code: error.extensions?.code,
        path: error.path
      };
    }
  });

  await server.start();
  server.applyMiddleware({ app: app as any, path: '/graphql' });

  const httpServer = createServer(app);

  app.get('/health', async (req, res) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      await redis.ping();

      res.json({ 
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        services: {
          database: 'connected',
          redis: 'connected',
          graphql: 'ready'
        }
      });
    } catch (error) {
      res.status(500).json({
        status: 'error',
        timestamp: new Date().toISOString(),
        error: error.message
      });
    }
  });

  app.get('/', (req, res) => {
    res.json({
      message: 'Real-Time Auction Platform API Gateway - Phase 1',
      version: '1.0.0',
      endpoints: {
        graphql: '/graphql',
        health: '/health'
      },
      features: [
        'JWT Authentication',
        'Real-time Bidding',
        'Auction Management',
        'WebSocket Support'
      ]
    });
  });

  const PORT = process.env.PORT || 4000;

  httpServer.listen(PORT, () => {
    console.log('🚀 Real-Time Auction Platform - Phase 1');
    console.log('==========================================');
    console.log(`🎮 GraphQL endpoint: http://localhost:${PORT}/graphql`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log('==========================================');
    console.log('✅ Server ready for real-time bidding!');
  });

  process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down gracefully');
    await prisma.$disconnect();
    redis.disconnect();
    process.exit(0);
  });
}

startServer().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
