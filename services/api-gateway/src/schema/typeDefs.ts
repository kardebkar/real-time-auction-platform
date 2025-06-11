import { gql } from 'apollo-server-express';

export const typeDefs = gql`
  scalar DateTime
  scalar JSON

  type User {
    id: ID!
    email: String!
    username: String!
    firstName: String!
    lastName: String!
    avatar: String
    role: UserRole!
    emailVerified: Boolean!
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relations
    auctions: [Auction!]!
    bids: [Bid!]!
    watchedAuctions: [Auction!]!
  }

  type Category {
    id: ID!
    name: String!
    description: String
    parentId: ID
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Relations
    parent: Category
    children: [Category!]!
    auctions: [Auction!]!
  }

  type Auction {
    id: ID!
    title: String!
    description: String!
    images: [String!]!
    startingPrice: Float!
    currentPrice: Float!
    reservePrice: Float
    status: AuctionStatus!
    startTime: DateTime!
    endTime: DateTime!
    createdAt: DateTime!
    updatedAt: DateTime!
    
    # Computed fields
    timeRemaining: Int!
    bidCount: Int!
    watcherCount: Int!
    isWatched(userId: ID): Boolean!
    
    # Relations
    seller: User!
    category: Category!
    bids: [Bid!]!
    watchers: [User!]!
    highestBid: Bid
  }

  type Bid {
    id: ID!
    amount: Float!
    isWinning: Boolean!
    isAutoBid: Boolean!
    timestamp: DateTime!
    
    # Relations
    auction: Auction!
    bidder: User!
  }

  type Notification {
    id: ID!
    type: NotificationType!
    title: String!
    message: String!
    data: JSON
    read: Boolean!
    createdAt: DateTime!
    
    # Relations
    user: User!
  }

  # Enums
  enum UserRole {
    USER
    ADMIN
    SELLER
  }

  enum AuctionStatus {
    DRAFT
    ACTIVE
    ENDED
    CANCELLED
  }

  enum NotificationType {
    BID_PLACED
    BID_OUTBID
    AUCTION_WON
    AUCTION_ENDED
    AUCTION_STARTED
    PAYMENT_REQUIRED
    PAYMENT_RECEIVED
  }

  # Input Types
  input RegisterInput {
    email: String!
    username: String!
    password: String!
    firstName: String!
    lastName: String!
  }

  input LoginInput {
    email: String!
    password: String!
  }

  input CreateAuctionInput {
    title: String!
    description: String!
    images: [String!]!
    startingPrice: Float!
    reservePrice: Float
    categoryId: ID!
    startTime: DateTime!
    endTime: DateTime!
  }

  input UpdateAuctionInput {
    title: String
    description: String
    images: [String!]
    reservePrice: Float
    endTime: DateTime
  }

  input AuctionFilters {
    status: AuctionStatus
    categoryId: ID
    minPrice: Float
    maxPrice: Float
    search: String
  }

  input PaginationInput {
    limit: Int = 20
    offset: Int = 0
    sortBy: String = "createdAt"
    sortOrder: String = "DESC"
  }

  # Response Types
  type AuthPayload {
    token: String!
    refreshToken: String!
    user: User!
  }

  type BidPayload {
    bid: Bid!
    auction: Auction!
    previousHighBid: Bid
  }

  type AuctionConnection {
    auctions: [Auction!]!
    totalCount: Int!
    hasMore: Boolean!
  }

  # Subscription Types
  type AuctionUpdate {
    auction: Auction!
    type: String!
    timestamp: DateTime!
  }

  type BidUpdate {
    bid: Bid!
    auction: Auction!
    previousHighBid: Bid
  }

  type AuctionEndedUpdate {
    auction: Auction!
    winningBid: Bid
    soldPrice: Float
  }

  # Root Types
  type Query {
    # Authentication
    me: User
    
    # Users
    user(id: ID!): User
    users(pagination: PaginationInput): [User!]!
    
    # Auctions
    auctions(filters: AuctionFilters, pagination: PaginationInput): AuctionConnection!
    auction(id: ID!): Auction
    searchAuctions(query: String!, pagination: PaginationInput): AuctionConnection!
    featuredAuctions(limit: Int = 10): [Auction!]!
    endingSoonAuctions(limit: Int = 10): [Auction!]!
    
    # Categories
    categories: [Category!]!
    category(id: ID!): Category
    
    # Bids
    auctionBids(auctionId: ID!, pagination: PaginationInput): [Bid!]!
    userBids(userId: ID!, pagination: PaginationInput): [Bid!]!
    
    # Notifications
    notifications(pagination: PaginationInput): [Notification!]!
    unreadNotificationsCount: Int!
  }

  type Mutation {
    # Authentication
    register(input: RegisterInput!): AuthPayload!
    login(input: LoginInput!): AuthPayload!
    refreshToken(token: String!): AuthPayload!
    logout: Boolean!
    
    # Profile
    updateProfile(firstName: String, lastName: String, avatar: String): User!
    changePassword(currentPassword: String!, newPassword: String!): Boolean!
    
    # Auctions
    createAuction(input: CreateAuctionInput!): Auction!
    updateAuction(id: ID!, input: UpdateAuctionInput!): Auction!
    deleteAuction(id: ID!): Boolean!
    startAuction(id: ID!): Auction!
    cancelAuction(id: ID!): Auction!
    
    # Bidding
    placeBid(auctionId: ID!, amount: Float!): BidPayload!
    
    # Watching
    watchAuction(auctionId: ID!): Boolean!
    unwatchAuction(auctionId: ID!): Boolean!
    
    # Categories (Admin only)
    createCategory(name: String!, description: String, parentId: ID): Category!
    updateCategory(id: ID!, name: String, description: String): Category!
    deleteCategory(id: ID!): Boolean!
    
    # Notifications
    markNotificationRead(id: ID!): Notification!
    markAllNotificationsRead: Boolean!
  }

  type Subscription {
    # Auction updates
    auctionUpdated(auctionId: ID!): AuctionUpdate!
    bidPlaced(auctionId: ID!): BidUpdate!
    auctionStarted: Auction!
    auctionEnded: AuctionEndedUpdate!
    
    # User notifications
    userNotifications(userId: ID!): Notification!
    
    # System-wide events
    newAuctions: Auction!
  }
`;