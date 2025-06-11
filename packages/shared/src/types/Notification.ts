export interface Notification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  message: string;
  data?: Record<string, any>;
  read: boolean;
  createdAt: Date;
}

export enum NotificationType {
  BID_PLACED = 'BID_PLACED',
  BID_OUTBID = 'BID_OUTBID',
  AUCTION_WON = 'AUCTION_WON',
  AUCTION_ENDED = 'AUCTION_ENDED',
  AUCTION_STARTED = 'AUCTION_STARTED',
  PAYMENT_REQUIRED = 'PAYMENT_REQUIRED',
  PAYMENT_RECEIVED = 'PAYMENT_RECEIVED'
}