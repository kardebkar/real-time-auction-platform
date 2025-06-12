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
