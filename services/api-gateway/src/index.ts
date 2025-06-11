import express from 'express';
import { ApolloServer } from 'apollo-server-express';
import { createServer } from 'http';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { typeDefs } from './schema/typeDefs';
import { resolvers } from './resolvers';
import { Context } from './types/context';

const prisma = new PrismaClient();

async function startServer() {
  const app = express();

  // Minimal middleware setup
  app.use(cors());
  app.use(express.json());

  // GraphQL Server with minimal config
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    context: ({ req }): Context => {
      const token = req.headers.authorization?.replace('Bearer ', '');
      let user = undefined;

      if (token) {
        try {
          const payload: any = jwt.verify(token, 'secret');
          user = { id: payload.userId };
        } catch (err: any) {
          console.warn('Invalid token:', err.message);
        }
      }

      return { user, req, prisma };
    },
    introspection: true
  });

  await server.start();
  server.applyMiddleware({ app: app as any });

  const httpServer = createServer(app);

  // Health endpoint
  app.get('/health', (req, res) => {
    res.json({ 
      status: 'ok', 
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    });
  });

  // Root endpoint
  app.get('/', (req, res) => {
    res.json({
      message: 'Real-Time Auction Platform API Gateway',
      graphql: '/graphql',
      health: '/health'
    });
  });

  const PORT = 4000;

  httpServer.listen(PORT, () => {
    console.log(`🚀 Server ready at http://localhost:${PORT}${server.graphqlPath}`);
    console.log(`🎮 GraphQL endpoint: http://localhost:${PORT}/graphql`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
  });
}

startServer().catch(console.error);