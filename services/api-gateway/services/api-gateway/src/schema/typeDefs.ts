import { gql } from 'apollo-server-express';

export const typeDefs = gql`
  scalar DateTime
  scalar JSON

  type User {
    id: ID!
    email: String!
    firstName: String
    lastName: String
    role: UserRole!
    createdAt: DateTime!
    updatedAt: DateTime!
    auctions: [Auction!]!
    bids: [Bid!]!
  }

  enum UserRole {
    USER
    ADMIN
    MODERATOR
  }

  type Auction {
    id: ID!
    title: String!
    description: String!
    startingPrice: Float!
    currentPrice: Float!
    minimumIncrement: Float!
    startTime: DateTime!
    endTime: DateTime!
    status: AuctionStatus!
    images: [String!]!
    category: Category
    seller: User!
    bids: [Bid!]!
    bidCount: Int!
    watchers: Int!
    createdAt: DateTime!
    updatedAt: DateTime!
  }

  enum AuctionStatus {
    DRAFT
    SCHEDULED
    ACTIVE
    ENDED
    CANCELLED
  }

  type Category {
    id: ID!
    name: String!
    description: String
    auctions: [Auction!]!
  }

  type Bid {
    id: ID!
    amount: Float!
    timestamp: DateTime!
    user: User!
    auction: Auction!
  }

  type AuthPayload {
    token: String!
    user: User!
  }

  input RegisterInput {
    email: String!
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
    startingPrice: Float!
    minimumIncrement: Float = 1.0
    startTime: DateTime!
    endTime: DateTime!
    categoryId: ID!
    images: [String!]!
  }

  input PlaceBidInput {
    auctionId: ID!
    amount: Float!
  }

  input AuctionFilters {
    status: AuctionStatus
    categoryId: ID
    minPrice: Float
    maxPrice: Float
    search: String
  }

  input Pagination {
    limit: Int = 20
    offset: Int = 0
    sortBy: String = "createdAt"
    sortOrder: String = "DESC"
  }

  type BidError {
    message: String!
    auctionId: ID!
    amount: Float!
    timestamp: DateTime!
  }

  type AuctionUpdate {
    id: ID!
    currentPrice: Float!
    bidCount: Int!
    lastBidTime: DateTime
  }

  type Query {
    me: User
    auctions(filters: AuctionFilters, pagination: Pagination): [Auction!]!
    auction(id: ID!): Auction
    categories: [Category!]!
    auctionBids(auctionId: ID!, limit: Int): [Bid!]!
    currentHighestBid(auctionId: ID!): Bid
  }

  type Mutation {
    register(input: RegisterInput!): AuthPayload!
    login(input: LoginInput!): AuthPayload!
    createAuction(input: CreateAuctionInput!): Auction!
    placeBid(input: PlaceBidInput!): Bid!
  }

  type Subscription {
    bidPlaced(auctionId: ID!): Bid!
    auctionUpdated(auctionId: ID!): AuctionUpdate!
    bidError: BidError!
  }
`;
