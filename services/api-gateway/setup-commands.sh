#!/bin/bash

echo "🚀 Setting up Phase 1 Complete Structure..."

# Step 1: Create directory structure
echo "📁 Creating directory structure..."
mkdir -p services/api-gateway/src/{types,services,resolvers,schema,websocket,middleware,utils}
mkdir -p services/api-gateway/prisma/migrations
mkdir -p packages/shared/src/types
mkdir -p apps/web/src
mkdir -p docs
mkdir -p tests

# Step 2: Create essential files in services/api-gateway/src/types/
echo "📝 Creating type definitions..."

cat > services/api-gateway/src/types/context.ts << 'EOF'
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
EOF

# Step 3: Create AuthService
cat > services/api-gateway/src/services/AuthService.ts << 'EOF'
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

export class AuthService {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  async register(email: string, password: string, firstName: string, lastName: string) {
    const existingUser = await this.prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      throw new Error('User with this email already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await this.prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        firstName,
        lastName,
        role: 'USER'
      }
    });

    const token = this.generateToken(user.id);

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
  }

  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({
      where: { email }
    });

    if (!user) {
      throw new Error('Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new Error('Invalid email or password');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() }
    });

    const token = this.generateToken(user.id);

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
  }

  private generateToken(userId: string): string {
    return jwt.sign(
      { userId },
      process.env.JWT_SECRET || 'secret',
      { expiresIn: process.env.JWT_EXPIRY || '1h' }
    );
  }
}
EOF

# Step 4: Create BiddingService
cat > services/api-gateway/src/services/BiddingService.ts << 'EOF'
import { PubSub } from 'graphql-subscriptions';
import { PrismaClient } from '@prisma/client';
import { Redis } from 'ioredis';

export class BiddingService {
  private pubsub: PubSub;
  private prisma: PrismaClient;
  private redis: Redis;

  constructor(pubsub: PubSub, prisma: PrismaClient, redis: Redis) {
    this.pubsub = pubsub;
    this.prisma = prisma;
    this.redis = redis;
  }

  async placeBid(auctionId: string, amount: number, userId: string) {
    try {
      const auction = await this.prisma.auction.findUnique({
        where: { id: auctionId },
        include: {
          bids: {
            orderBy: { amount: 'desc' },
            take: 1,
            include: { user: true }
          }
        }
      });

      if (!auction) {
        throw new Error('Auction not found');
      }

      if (auction.status !== 'ACTIVE') {
        throw new Error('Auction is not active');
      }

      const now = new Date();
      if (now < auction.startTime || now > auction.endTime) {
        throw new Error('Auction is not currently active');
      }

      const currentHighestBid = auction.bids[0]?.amount || auction.startingPrice;
      const minimumBid = currentHighestBid + auction.minimumIncrement;

      if (amount < minimumBid) {
        throw new Error(`Bid must be at least $${minimumBid}`);
      }

      if (auction.bids[0]?.userId === userId) {
        throw new Error('You are already the highest bidder');
      }

      const bid = await this.prisma.bid.create({
        data: {
          amount,
          auctionId,
          userId,
          timestamp: new Date()
        },
        include: {
          user: {
            select: { id: true, email: true, firstName: true, lastName: true }
          },
          auction: {
            select: { id: true, title: true, currentPrice: true }
          }
        }
      });

      await this.prisma.auction.update({
        where: { id: auctionId },
        data: { 
          currentPrice: amount,
          bidCount: { increment: 1 }
        }
      });

      await this.redis.setex(
        `auction:${auctionId}:highest_bid`,
        3600,
        JSON.stringify(bid)
      );

      await this.pubsub.publish(`BID_PLACED_${auctionId}`, {
        bidPlaced: {
          id: bid.id,
          amount: bid.amount,
          timestamp: bid.timestamp,
          user: bid.user,
          auction: bid.auction
        }
      });

      return bid;

    } catch (error) {
      await this.pubsub.publish(`BID_ERROR_${userId}`, {
        bidError: {
          message: error.message,
          auctionId,
          amount,
          timestamp: new Date()
        }
      });
      throw error;
    }
  }

  async getAuctionBidHistory(auctionId: string, limit = 50) {
    return await this.prisma.bid.findMany({
      where: { auctionId },
      orderBy: { timestamp: 'desc' },
      take: limit,
      include: {
        user: {
          select: { id: true, email: true, firstName: true, lastName: true }
        }
      }
    });
  }

  async getCurrentHighestBid(auctionId: string) {
    const cached = await this.redis.get(`auction:${auctionId}:highest_bid`);
    if (cached) {
      return JSON.parse(cached);
    }

    const bid = await this.prisma.bid.findFirst({
      where: { auctionId },
      orderBy: { amount: 'desc' },
      include: {
        user: {
          select: { id: true, email: true, firstName: true, lastName: true }
        }
      }
    });

    if (bid) {
      await this.redis.setex(
        `auction:${auctionId}:highest_bid`,
        3600,
        JSON.stringify(bid)
      );
    }

    return bid;
  }
}
EOF

# Step 5: Create GraphQL Schema
cat > services/api-gateway/src/schema/typeDefs.ts << 'EOF'
import { gql } from 'apollo-server-express';

export const typeDefs = gql`
  scalar DateTime
  scalar JSON

  type User {
    id: ID!
    email: String!
    firstName: String
    lastName: String
    role: UserRole!
    createdAt: DateTime!
    updatedAt: DateTime!
    auctions: [Auction!]!
    bids: [Bid!]!
  }

  enum UserRole {
    USER
    ADMIN
    MODERATOR
  }

  type Auction {
    id: ID!
    title: String!
    description: String!
    startingPrice: Float!
    currentPrice: Float!
    minimumIncrement: Float!
    startTime: DateTime!
    endTime: DateTime!
    status: AuctionStatus!
    images: [String!]!
    category: Category
    seller: User!
    bids: [Bid!]!
    bidCount: Int!
    watchers: Int!
    createdAt: DateTime!
    updatedAt: DateTime!
  }

  enum AuctionStatus {
    DRAFT
    SCHEDULED
    ACTIVE
    ENDED
    CANCELLED
  }

  type Category {
    id: ID!
    name: String!
    description: String
    auctions: [Auction!]!
  }

  type Bid {
    id: ID!
    amount: Float!
    timestamp: DateTime!
    user: User!
    auction: Auction!
  }

  type AuthPayload {
    token: String!
    user: User!
  }

  input RegisterInput {
    email: String!
    password: String!
    firstName: String!
    lastName: String!
  }

  input LoginInput {
    email: String!
    password: String!
  }

  input CreateAuctionInput {
    title: String!
    description: String!
    startingPrice: Float!
    minimumIncrement: Float = 1.0
    startTime: DateTime!
    endTime: DateTime!
    categoryId: ID!
    images: [String!]!
  }

  input PlaceBidInput {
    auctionId: ID!
    amount: Float!
  }

  input AuctionFilters {
    status: AuctionStatus
    categoryId: ID
    minPrice: Float
    maxPrice: Float
    search: String
  }

  input Pagination {
    limit: Int = 20
    offset: Int = 0
    sortBy: String = "createdAt"
    sortOrder: String = "DESC"
  }

  type BidError {
    message: String!
    auctionId: ID!
    amount: Float!
    timestamp: DateTime!
  }

  type AuctionUpdate {
    id: ID!
    currentPrice: Float!
    bidCount: Int!
    lastBidTime: DateTime
  }

  type Query {
    me: User
    auctions(filters: AuctionFilters, pagination: Pagination): [Auction!]!
    auction(id: ID!): Auction
    categories: [Category!]!
    auctionBids(auctionId: ID!, limit: Int): [Bid!]!
    currentHighestBid(auctionId: ID!): Bid
  }

  type Mutation {
    register(input: RegisterInput!): AuthPayload!
    login(input: LoginInput!): AuthPayload!
    createAuction(input: CreateAuctionInput!): Auction!
    placeBid(input: PlaceBidInput!): Bid!
  }

  type Subscription {
    bidPlaced(auctionId: ID!): Bid!
    auctionUpdated(auctionId: ID!): AuctionUpdate!
    bidError: BidError!
  }
`;
EOF

# Step 6: Create Resolvers
cat > services/api-gateway/src/resolvers/index.ts << 'EOF'
import { PubSub } from 'graphql-subscriptions';
import { AuthService } from '../services/AuthService';
import { BiddingService } from '../services/BiddingService';
import { Context } from '../types/context';
import { Redis } from 'ioredis';

const pubsub = new PubSub();
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

export const resolvers = {
  DateTime: {
    serialize: (date: Date) => date.toISOString(),
    parseValue: (value: string) => new Date(value),
    parseLiteral: (ast: any) => new Date(ast.value),
  },

  JSON: {
    serialize: (value: any) => value,
    parseValue: (value: any) => value,
    parseLiteral: (ast: any) => JSON.parse(ast.value),
  },

  Query: {
    me: async (_: any, __: any, context: Context) => {
      if (!context.user) throw new Error('Not authenticated');
      
      return await context.prisma.user.findUnique({
        where: { id: context.user.id }
      });
    },

    auctions: async (_: any, args: any, context: Context) => {
      const { filters = {}, pagination = {} } = args;
      const { limit = 20, offset = 0, sortBy = 'createdAt', sortOrder = 'DESC' } = pagination;

      const where: any = {};
      
      if (filters.status) where.status = filters.status;
      if (filters.categoryId) where.categoryId = filters.categoryId;
      if (filters.minPrice || filters.maxPrice) {
        where.currentPrice = {};
        if (filters.minPrice) where.currentPrice.gte = filters.minPrice;
        if (filters.maxPrice) where.currentPrice.lte = filters.maxPrice;
      }
      if (filters.search) {
        where.OR = [
          { title: { contains: filters.search, mode: 'insensitive' } },
          { description: { contains: filters.search, mode: 'insensitive' } }
        ];
      }

      return await context.prisma.auction.findMany({
        where,
        take: limit,
        skip: offset,
        orderBy: { [sortBy]: sortOrder.toLowerCase() },
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

    auction: async (_: any, { id }: any, context: Context) => {
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

      await context.prisma.auction.update({
        where: { id },
        data: { viewCount: { increment: 1 } }
      });

      return auction;
    },

    categories: async (_: any, __: any, context: Context) => {
      return await context.prisma.category.findMany({
        where: { isActive: true },
        orderBy: { name: 'asc' }
      });
    },

    auctionBids: async (_: any, { auctionId, limit = 50 }: any, context: Context) => {
      const biddingService = new BiddingService(pubsub, context.prisma, redis);
      return await biddingService.getAuctionBidHistory(auctionId, limit);
    },

    currentHighestBid: async (_: any, { auctionId }: any, context: Context) => {
      const biddingService = new BiddingService(pubsub, context.prisma, redis);
      return await biddingService.getCurrentHighestBid(auctionId);
    }
  },

  Mutation: {
    register: async (_: any, { input }: any, context: Context) => {
      const authService = new AuthService(context.prisma);
      return await authService.register(
        input.email,
        input.password,
        input.firstName,
        input.lastName
      );
    },

    login: async (_: any, { input }: any, context: Context) => {
      const authService = new AuthService(context.prisma);
      return await authService.login(input.email, input.password);
    },

    createAuction: async (_: any, { input }: any, context: Context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const auction = await context.prisma.auction.create({
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

      return auction;
    },

    placeBid: async (_: any, { input }: any, context: Context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const biddingService = new BiddingService(pubsub, context.prisma, redis);
      return await biddingService.placeBid(
        input.auctionId,
        input.amount,
        context.user.id
      );
    }
  },

  Subscription: {
    bidPlaced: {
      subscribe: () => pubsub.asyncIterator(['BID_PLACED'])
    },

    auctionUpdated: {
      subscribe: () => pubsub.asyncIterator(['AUCTION_UPDATED'])
    },

    bidError: {
      subscribe: () => pubsub.asyncIterator(['BID_ERROR'])
    }
  }
};
EOF

# Step 7: Create main index.ts
cat > services/api-gateway/src/index.ts << 'EOF'
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
EOF

echo "✅ All source files created successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Copy .env files: cp services/api-gateway/.env.example services/api-gateway/.env"
echo "2. Install dependencies: cd services/api-gateway && npm install"
echo "3. Create Prisma schema and run setup"