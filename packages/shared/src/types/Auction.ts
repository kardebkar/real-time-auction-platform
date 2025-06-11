export interface AuctionItem {
  id: string;
  title: string;
  description: string;
  images: string[];
  startingPrice: number;
  currentPrice: number;
  reservePrice?: number;
  categoryId: string;
  sellerId: string;
  status: AuctionStatus;
  startTime: Date;
  endTime: Date;
  bidCount: number;
  watcherCount: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateAuctionInput {
  title: string;
  description: string;
  images: string[];
  startingPrice: number;
  reservePrice?: number;
  categoryId: string;
  startTime: Date;
  endTime: Date;
}

export interface UpdateAuctionInput {
  title?: string;
  description?: string;
  images?: string[];
  reservePrice?: number;
  endTime?: Date;
}

export enum AuctionStatus {
  DRAFT = 'DRAFT',
  ACTIVE = 'ACTIVE',
  ENDED = 'ENDED',
  CANCELLED = 'CANCELLED'
}
