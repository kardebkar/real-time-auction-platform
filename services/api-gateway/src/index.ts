import express from 'express';
import { ApolloServer } from 'apollo-server-express';
import { createServer } from 'http';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';
import { typeDefs } from './schema/typeDefs';

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

const resolvers = {
  DateTime: {
    serialize: (date: Date) => date.toISOString(),
    parseValue: (value: string) => new Date(value),
    parseLiteral: (ast: any) => new Date(ast.value),
  },

  Query: {
    me: async (_: any, __: any, context: any) => {
      if (!context.user) throw new Error('Not authenticated');
      return await context.prisma.user.findUnique({
        where: { id: context.user.id }
      });
    },

    auctions: async (_: any, args: any, context: any) => {
      return await context.prisma.auction.findMany({
        include: {
          category: true,
          seller: {
            select: { id: true, email: true, firstName: true, lastName: true }
          },
          bids: {
            orderBy: { amount: 'desc' },
            take: 1,
            include: {
              user: {
                select: { id: true, email: true, firstName: true, lastName: true }
              }
            }
          }
        }
      });
    },

    auction: async (_: any, { id }: any, context: any) => {
      const auction = await context.prisma.auction.findUnique({
        where: { id },
        include: {
          category: true,
          seller: {
            select: { id: true, email: true, firstName: true, lastName: true }
          },
          bids: {
            orderBy: { amount: 'desc' },
            include: {
              user: {
                select: { id: true, email: true, firstName: true, lastName: true }
              }
            }
          }
        }
      });

      if (!auction) {
        throw new Error('Auction not found');
      }

      return auction;
    },

    categories: async (_: any, __: any, context: any) => {
      return await context.prisma.category.findMany({
        where: { isActive: true }
      });
    },

    auctionBids: async (_: any, { auctionId, limit = 50 }: any, context: any) => {
      return await context.prisma.bid.findMany({
        where: { auctionId },
        orderBy: { timestamp: 'desc' },
        take: limit,
        include: {
          user: {
            select: { id: true, email: true, firstName: true, lastName: true }
          }
        }
      });
    },

    currentHighestBid: async (_: any, { auctionId }: any, context: any) => {
      return await context.prisma.bid.findFirst({
        where: { auctionId },
        orderBy: { amount: 'desc' },
        include: {
          user: {
            select: { id: true, email: true, firstName: true, lastName: true }
          }
        }
      });
    }
  },

  Mutation: {
    login: async (_: any, { input }: any, context: any) => {
      const bcrypt = require('bcryptjs');
      const user = await context.prisma.user.findUnique({
        where: { email: input.email }
      });

      if (!user || !await bcrypt.compare(input.password, user.password)) {
        throw new Error('Invalid email or password');
      }

      const token = jwt.sign({ userId: user.id }, 'secret', { expiresIn: '1h' });

      return {
        token,
        user: { 
          id: user.id, 
          email: user.email, 
          firstName: user.firstName, 
          lastName: user.lastName, 
          role: user.role 
        }
      };
    },

    register: async (_: any, { input }: any, context: any) => {
      const bcrypt = require('bcryptjs');
      
      const existingUser = await context.prisma.user.findUnique({
        where: { email: input.email }
      });

      if (existingUser) {
        throw new Error('User with this email already exists');
      }

      const hashedPassword = await bcrypt.hash(input.password, 10);

      const user = await context.prisma.user.create({
        data: {
          email: input.email,
          password: hashedPassword,
          firstName: input.firstName,
          lastName: input.lastName,
          role: 'USER'
        }
      });

      const token = jwt.sign({ userId: user.id }, 'secret', { expiresIn: '1h' });

      return {
        token,
        user: {
          id: user.id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          role: user.role
        }
      };
    },

    createAuction: async (_: any, { input }: any, context: any) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      return await context.prisma.auction.create({
        data: {
          title: input.title,
          description: input.description,
          startingPrice: input.startingPrice,
          currentPrice: input.startingPrice,
          minimumIncrement: input.minimumIncrement || 1.0,
          startTime: new Date(input.startTime),
          endTime: new Date(input.endTime),
          images: input.images || [],
          categoryId: input.categoryId,
          sellerId: context.user.id,
          status: 'DRAFT'
        },
        include: {
          category: true,
          seller: {
            select: { id: true, email: true, firstName: true, lastName: true }
          }
        }
      });
    },

    placeBid: async (_: any, { input }: any, context: any) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const { auctionId, amount } = input;
      
      // Get auction with current highest bid
      const auction = await context.prisma.auction.findUnique({
        where: { id: auctionId },
        include: {
          bids: {
            orderBy: { amount: 'desc' },
            take: 1
          }
        }
      });

      if (!auction) {
        throw new Error('Auction not found');
      }

      if (auction.status !== 'ACTIVE') {
        throw new Error('Auction is not active');
      }

      // Check timing
      const now = new Date();
      if (now < auction.startTime || now > auction.endTime) {
        throw new Error('Auction is not currently active');
      }

      // Calculate minimum bid
      const currentHighestBid = auction.bids[0]?.amount || auction.startingPrice;
      const minimumBid = currentHighestBid + auction.minimumIncrement;

      if (amount < minimumBid) {
        throw new Error(`Bid must be at least $${minimumBid}`);
      }

      // Check if user is already highest bidder
      if (auction.bids[0]?.userId === context.user.id) {
        throw new Error('You are already the highest bidder');
      }

      // Create the bid
      const bid = await context.prisma.bid.create({
        data: {
          amount,
          auctionId,
          userId: context.user.id,
          timestamp: new Date()
        },
        include: {
          user: {
            select: { id: true, email: true, firstName: true, lastName: true }
          },
          auction: {
            select: { id: true, title: true }
          }
        }
      });

      // Update auction current price
      await context.prisma.auction.update({
        where: { id: auctionId },
        data: { 
          currentPrice: amount,
          bidCount: { increment: 1 }
        }
      });

      return bid;
    }
  }
};

async function startServer() {
  const app = express();

  // Enhanced CORS configuration for Apollo Studio
  app.use(cors({
    origin: [
      'http://localhost:3000',
      'http://localhost:3005', 
      'http://localhost:3006',
      'https://studio.apollographql.com',
      'https://sandbox.apollo.dev',
      'http://localhost:4000',
      // Allow any localhost origin for development
      /^http:\/\/localhost:\d+$/,
      /^https:\/\/studio\.apollographql\.com$/
    ],
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type', 
      'Authorization', 
      'Apollo-Require-Preflight',
      'x-apollo-operation-name',
      'apollo-require-preflight'
    ],
    optionsSuccessStatus: 200
  }));

  // Handle preflight requests explicitly
  app.options('*', cors());
  
  app.use(express.json({ limit: '10mb' }));

  const server = new ApolloServer({
    typeDefs,
    resolvers,
    context: ({ req }: any) => {
      let user = undefined;
      const authHeader = req.headers.authorization;

      if (authHeader) {
        try {
          const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : authHeader;
          const payload: any = jwt.verify(token, 'secret');
          user = { id: payload.userId };
        } catch (err: any) {
          console.log('Auth failed:', err.message);
        }
      }

      return { user, req, prisma, redis };
    },
    introspection: true,
    playground: true,
    cors: false // We handle CORS above
  });

  await server.start();
  
  // Apply GraphQL middleware without CORS (we handle it above)
  server.applyMiddleware({ 
    app: app as any, 
    path: '/graphql',
    cors: false
  });

  const httpServer = createServer(app);

  // Health endpoint
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
        error: error.message
      });
    }
  });

  // Test CORS endpoint
  app.get('/test-cors', (req, res) => {
    res.json({
      message: 'CORS is working!',
      origin: req.headers.origin,
      method: req.method,
      timestamp: new Date().toISOString()
    });
  });

  // Root endpoint
  app.get('/', (req, res) => {
    res.json({
      message: 'Real-Time Auction Platform API Gateway - Phase 1',
      version: '1.0.0',
      endpoints: {
        graphql: '/graphql',
        playground: '/graphql',
        health: '/health',
        testCors: '/test-cors'
      }
    });
  });

  const PORT = process.env.PORT || 4000;

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 Real-Time Auction Platform - Phase 1');
    console.log('==========================================');
    console.log(`🎮 GraphQL endpoint: http://localhost:${PORT}/graphql`);
    console.log(`🎮 Local Playground: http://localhost:${PORT}/graphql`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🧪 Test CORS: http://localhost:${PORT}/test-cors`);
    console.log('==========================================');
    console.log('✅ Server ready with enhanced CORS support!');
    console.log('✅ Apollo Studio should work now!');
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