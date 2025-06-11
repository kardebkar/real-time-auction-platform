import { Bid } from './Bid';
import { AuctionItem } from './Auction';

export interface WebSocketMessage {
  type: WebSocketMessageType;
  payload: any;
  timestamp: Date;
  userId?: string;
}

export enum WebSocketMessageType {
  // Bidding
  BID_PLACED = 'BID_PLACED',
  BID_CONFIRMED = 'BID_CONFIRMED',
  BID_ERROR = 'BID_ERROR',
  
  // Auction lifecycle
  AUCTION_STARTED = 'AUCTION_STARTED',
  AUCTION_ENDED = 'AUCTION_ENDED',
  AUCTION_UPDATED = 'AUCTION_UPDATED',
  
  // User presence
  USER_JOINED = 'USER_JOINED',
  USER_LEFT = 'USER_LEFT',
  USER_TYPING = 'USER_TYPING',
  
  // Notifications
  NOTIFICATION = 'NOTIFICATION'
}

export interface BidPlacedEvent {
  auctionId: string;
  bid: Bid;
  auction: AuctionItem;
  previousHighBid?: Bid;
}

export interface AuctionEndedEvent {
  auctionId: string;
  auction: AuctionItem;
  winningBid?: Bid;
  soldPrice?: number;
}