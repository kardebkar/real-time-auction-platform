import { gql } from '@apollo/client';

export const LOGIN_MUTATION = gql`
  mutation Login($input: LoginInput!) {
    login(input: $input) {
      token
      user {
        id
        email
        firstName
        lastName
        role
      }
    }
  }
`;

export const REGISTER_MUTATION = gql`
  mutation Register($input: CreateUserInput!) {
    register(input: $input) {
      token
      user {
        id
        email
        firstName
        lastName
        role
      }
    }
  }
`;

export const GET_AUCTIONS = gql`
  query GetAuctions($filters: AuctionFilters, $pagination: Pagination) {
    auctions(filters: $filters, pagination: $pagination) {
      id
      title
      description
      startingPrice
      currentPrice
      bidCount
      endTime
      status
      category {
        id
        name
      }
      seller {
        id
        firstName
        lastName
      }
    }
  }
`;

export const GET_CATEGORIES = gql`
  query GetCategories {
    categories {
      id
      name
    }
  }
`;

export const GET_AUCTION_DETAIL = gql`
  query GetAuctionDetail($id: ID!) {
    auction(id: $id) {
      id
      title
      description
      startingPrice
      currentPrice
      bidCount
      endTime
      status
      category {
        id
        name
      }
      seller {
        id
        firstName
        lastName
      }
      bids {
        id
        amount
        timestamp
        user {
          id
          firstName
          lastName
        }
      }
    }
  }
`;

export const PLACE_BID_MUTATION = gql`
  mutation PlaceBid($input: PlaceBidInput!) {
    placeBid(input: $input) {
      id
      amount
      timestamp
      user {
        id
        firstName
        lastName
      }
      auction {
        id
        currentPrice
        bidCount
      }
    }
  }
`;