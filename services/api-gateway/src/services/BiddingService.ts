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
      // Get auction with current highest bid
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

      // Validate auction status
      if (auction.status !== 'ACTIVE') {
        throw new Error('Auction is not active');
      }

      // Validate timing
      const now = new Date();
      if (now < auction.startTime || now > auction.endTime) {
        throw new Error('Auction is not currently active');
      }

      // Validate bid amount
      const currentHighestBid = auction.bids[0]?.amount || auction.startingPrice;
      const minimumBid = currentHighestBid + auction.minimumIncrement;

      if (amount < minimumBid) {
        throw new Error(`Bid must be at least $${minimumBid}`);
      }

      // Check if user is trying to outbid themselves
      if (auction.bids[0]?.userId === userId) {
        throw new Error('You are already the highest bidder');
      }

      // Create the bid
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

      // Update auction current price
      await this.prisma.auction.update({
        where: { id: auctionId },
        data: { 
          currentPrice: amount,
          bidCount: { increment: 1 }
        }
      });

      // Cache bid in Redis for fast access
      await this.redis.setex(
        `auction:${auctionId}:highest_bid`,
        3600, // 1 hour TTL
        JSON.stringify(bid)
      );

      // Publish real-time update
      await this.pubsub.publish(`BID_PLACED_${auctionId}`, {
        bidPlaced: {
          id: bid.id,
          amount: bid.amount,
          timestamp: bid.timestamp,
          user: bid.user,
          auction: bid.auction
        }
      });

      // Publish to general auction updates
      await this.pubsub.publish(`AUCTION_UPDATED_${auctionId}`, {
        auctionUpdated: {
          id: auction.id,
          currentPrice: amount,
          bidCount: auction.bidCount + 1,
          lastBidTime: bid.timestamp
        }
      });

      // Auto-extend auction if bid placed in last 5 minutes
      await this.handleAutomaticExtension(auction, bid.timestamp);

      return bid;

    } catch (error) {
      // Publish error to user
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

  private async handleAutomaticExtension(auction: any, bidTime: Date) {
    const timeUntilEnd = auction.endTime.getTime() - bidTime.getTime();
    const fiveMinutes = 5 * 60 * 1000; // 5 minutes in milliseconds

    if (timeUntilEnd <= fiveMinutes) {
      const newEndTime = new Date(auction.endTime.getTime() + fiveMinutes);
      
      await this.prisma.auction.update({
        where: { id: auction.id },
        data: { endTime: newEndTime }
      });

      // Notify all watchers about extension
      await this.pubsub.publish(`AUCTION_EXTENDED_${auction.id}`, {
        auctionExtended: {
          auctionId: auction.id,
          newEndTime,
          extensionMinutes: 5
        }
      });
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
    // Try Redis first for performance
    const cached = await this.redis.get(`auction:${auctionId}:highest_bid`);
    if (cached) {
      return JSON.parse(cached);
    }

    // Fallback to database
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
      // Cache for next time
      await this.redis.setex(
        `auction:${auctionId}:highest_bid`,
        3600,
        JSON.stringify(bid)
      );
    }

    return bid;
  }
}