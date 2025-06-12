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
