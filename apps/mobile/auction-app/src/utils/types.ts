export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
}

export interface Auction {
  id: string;
  title: string;
  description: string;
  startingPrice: number;
  currentPrice: number;
  bidCount: number;
  endTime: string;
  status: 'DRAFT' | 'ACTIVE' | 'ENDED' | 'SCHEDULED';
  category: {
    id: string;
    name: string;
  };
  seller: User;
  bids?: Bid[];
}

export interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  loading: boolean;
}

export interface RegisterData {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface Bid {
  id: string;
  amount: number;
  timestamp: string;
  user: {
    id: string;
    firstName: string;
    lastName: string;
  };
}