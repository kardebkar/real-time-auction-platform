import { PubSub, withFilter } from 'graphql-subscriptions';
import { BiddingService } from '../services/BiddingService';
import { Context } from '../types/context';

const pubsub = new PubSub();

export const biddingResolvers = {
  Mutation: {
    placeBid: async (_: any, { input }: any, context: Context) => {
      if (!context.user) {
        throw new Error('Authentication required');
      }

      const biddingService = new BiddingService(
        pubsub, 
        context.prisma, 
        context.redis
      );

      return await biddingService.placeBid(
        input.auctionId,
        input.amount,
        context.user.id
      );
    }
  },

  Subscription: {
    bidPlaced: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['BID_PLACED']),
        (payload, variables) => {
          return payload.bidPlaced.auction.id === variables.auctionId;
        }
      )
    },

    auctionUpdated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['AUCTION_UPDATED']),
        (payload, variables) => {
          return payload.auctionUpdated.id === variables.auctionId;
        }
      )
    },

    bidError: {
      subscribe: withFilter(
        () => pubsub.asyncIterator(['BID_ERROR']),
        (payload, variables, context) => {
          return context.user && payload.bidError.userId === context.user.id;
        }
      )
    }
  },

  Query: {
    auctionBids: async (_: any, { auctionId, limit }: any, context: Context) => {
      const biddingService = new BiddingService(
        pubsub,
        context.prisma,
        context.redis
      );

      return await biddingService.getAuctionBidHistory(auctionId, limit);
    },

    currentHighestBid: async (_: any, { auctionId }: any, context: Context) => {
      const biddingService = new BiddingService(
        pubsub,
        context.prisma,
        context.redis
      );

      return await biddingService.getCurrentHighestBid(auctionId);
    }
  }
};
