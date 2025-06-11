export const ERROR_MESSAGES = {
  // Authentication
  INVALID_CREDENTIALS: 'Invalid email or password',
  USER_NOT_FOUND: 'User not found',
  EMAIL_ALREADY_EXISTS: 'Email already exists',
  TOKEN_EXPIRED: 'Token has expired',
  
  // Auctions
  AUCTION_NOT_FOUND: 'Auction not found',
  AUCTION_NOT_ACTIVE: 'Auction is not active',
  AUCTION_ENDED: 'Auction has ended',
  
  // Bidding
  BID_TOO_LOW: 'Bid must be higher than current price',
  BID_ON_OWN_AUCTION: 'Cannot bid on your own auction',
  INSUFFICIENT_FUNDS: 'Insufficient funds',
  
  // General
  UNAUTHORIZED: 'Unauthorized access',
  FORBIDDEN: 'Forbidden action',
  VALIDATION_ERROR: 'Validation error',
  INTERNAL_ERROR: 'Internal server error'
} as const;

export const SUCCESS_MESSAGES = {
  USER_CREATED: 'User created successfully',
  LOGIN_SUCCESS: 'Login successful',
  BID_PLACED: 'Bid placed successfully',
  AUCTION_CREATED: 'Auction created successfully',
  AUCTION_UPDATED: 'Auction updated successfully'
} as const;