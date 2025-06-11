import { AuctionItem } from './Auction';

export interface Bid {
  id: string;
  auctionId: string;
  bidderId: string;
  amount: number;
  timestamp: Date;
  isWinning: boolean;
  isAutoBid: boolean;
}

export interface PlaceBidInput {
  auctionId: string;
  amount: number;
}

export interface BidResult {
  bid: Bid;
  auction: AuctionItem;
  previousHighBid?: Bid;
  position: number;
}