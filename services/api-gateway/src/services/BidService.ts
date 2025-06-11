import { PrismaClient } from '@prisma/client';
import { PubSub } from 'graphql-subscriptions';

export interface PlaceBidParams {
  auctionId: string;
  bidderId: string;
  amount: number;
}

export class BidService {
  constructor(
    private prisma: PrismaClient,
    private pubsub: PubSub
  ) {}

  async placeBid(params: PlaceBidParams) {
    const { auctionId, bidderId, amount } = params;

    // Check if auction exists and is active
    const auction = await this.prisma.auction.findUnique({
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

    if (new Date() > auction.endTime) {
      throw new Error('Auction has ended');
    }

    if (auction.sellerId === bidderId) {
      throw new Error('Cannot bid on your own auction');
    }

    const currentHighestBid = auction.bids[0];
    if (amount <= auction.currentPrice) {
      throw new Error(`Bid must be higher than current price of $${auction.currentPrice}`);
    }

    // Create the bid
    const bid = await this.prisma.bid.create({
      data: {
        auctionId,
        bidderId,
        amount,
        isWinning: true
      },
      include: {
        bidder: true,
        auction: true
      }
    });

    // Update auction current price and mark previous bids as not winning
    await this.prisma.auction.update({
      where: { id: auctionId },
      data: { currentPrice: amount }
    });

    if (currentHighestBid) {
      await this.prisma.bid.update({
        where: { id: currentHighestBid.id },
        data: { isWinning: false }
      });
    }

    // Get updated auction
    const updatedAuction = await this.prisma.auction.findUnique({
      where: { id: auctionId },
      include: {
        seller: true,
        category: true,
        bids: {
          orderBy: { amount: 'desc' },
          include: { bidder: true }
        }
      }
    });

    return {
      bid,
      auction: updatedAuction,
      previousHighBid: currentHighestBid
    };
  }
}