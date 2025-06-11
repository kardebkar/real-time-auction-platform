import { PubSub } from 'graphql-subscriptions';
import { AuthService } from '../services/AuthService';
import { Context } from '../types/context';

const pubsub = new PubSub();

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

      const [auctions, totalCount] = await Promise.all([
        context.prisma.auction.findMany({
          where,
          include: {
            seller: true,
            category: true,
            bids: {
              orderBy: { amount: 'desc' },
              take: 1,
              include: { bidder: true }
            },
            _count: {
              select: { bids: true, watchers: true }
            }
          },
          orderBy: { [sortBy]: sortOrder.toLowerCase() as 'asc' | 'desc' },
          take: limit,
          skip: offset,
        }),
        context.prisma.auction.count({ where })
      ]);

      return {
        auctions,
        totalCount,
        hasMore: offset + limit < totalCount,
      };
    },

    auction: async (_: any, { id }: any, context: Context) => {
      return await context.prisma.auction.findUnique({
        where: { id },
        include: {
          seller: true,
          category: true,
          bids: {
            orderBy: { timestamp: 'desc' },
            include: { bidder: true }
          },
          watchers: { include: { user: true } },
          _count: {
            select: { bids: true, watchers: true }
          }
        }
      });
    },

    categories: async (_: any, __: any, context: Context) => {
      return await context.prisma.category.findMany({
        include: {
          children: true,
          _count: { select: { auctions: true } }
        },
        orderBy: { name: 'asc' }
      });
    },
  },

  Mutation: {
    register: async (_: any, { input }: any, context: Context) => {
      const authService = new AuthService(context.prisma);
      return await authService.register(input);
    },

    login: async (_: any, { input }: any, context: Context) => {
      const authService = new AuthService(context.prisma);
      return await authService.login(input);
    },

    createCategory: async (_: any, { name, description, parentId }: any, context: Context) => {
      return await context.prisma.category.create({
        data: {
          name,
          description,
          parentId
        },
        include: {
          children: true,
          _count: { select: { auctions: true } }
        }
      });
    },
  },

  // Field resolvers
  Auction: {
    timeRemaining: (auction: any) => {
      const now = new Date();
      const endTime = new Date(auction.endTime);
      return Math.max(0, Math.floor((endTime.getTime() - now.getTime()) / 1000));
    },

    bidCount: (auction: any) => auction._count?.bids || 0,
    
    watcherCount: (auction: any) => auction._count?.watchers || 0,

    isWatched: async (auction: any, { userId }: any, context: Context) => {
      if (!userId) return false;
      
      const watcher = await context.prisma.auctionWatcher.findUnique({
        where: {
          userId_auctionId: {
            userId,
            auctionId: auction.id,
          }
        }
      });
      
      return !!watcher;
    },

    highestBid: (auction: any) => {
      return auction.bids?.[0] || null;
    },

    watchers: async (auction: any, _: any, context: Context) => {
      const watchers = await context.prisma.auctionWatcher.findMany({
        where: { auctionId: auction.id },
        include: { user: true }
      });
      return watchers.map(w => w.user);
    }
  },

  Category: {
    children: async (category: any, _: any, context: Context) => {
      return await context.prisma.category.findMany({
        where: { parentId: category.id },
        include: { _count: { select: { auctions: true } } }
      });
    },
  },

  User: {
    auctions: async (user: any, _: any, context: Context) => {
      return await context.prisma.auction.findMany({
        where: { sellerId: user.id },
        include: {
          category: true,
          _count: { select: { bids: true, watchers: true } }
        },
        orderBy: { createdAt: 'desc' }
      });
    },

    bids: async (user: any, _: any, context: Context) => {
      return await context.prisma.bid.findMany({
        where: { bidderId: user.id },
        include: { auction: true },
        orderBy: { timestamp: 'desc' }
      });
    },

    watchedAuctions: async (user: any, _: any, context: Context) => {
      const watchers = await context.prisma.auctionWatcher.findMany({
        where: { userId: user.id },
        include: { 
          auction: {
            include: {
              seller: true,
              category: true,
              _count: { select: { bids: true, watchers: true } }
            }
          }
        }
      });
      return watchers.map(w => w.auction);
    },
  },
};