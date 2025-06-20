#!/bin/bash

echo "🚀 STANDALONE MOBILE AUCTION APP SETUP"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🎯 Strategy: Standalone App (Best for Demos!)${NC}"
echo "=============================================="
echo ""
echo "Benefits of standalone approach:"
echo "✅ No monorepo conflicts"
echo "✅ Easier to share and demo"
echo "✅ Faster development"
echo "✅ Perfect for job interviews"
echo "✅ Same Phase 1 API integration"
echo ""

# Navigate to a clean location
echo -e "${YELLOW}📁 Creating standalone app in your Desktop...${NC}"
cd ~/Desktop

# Create directory
APP_DIR="auction-mobile-demo"
if [ -d "$APP_DIR" ]; then
    echo "Removing existing demo app..."
    rm -rf "$APP_DIR"
fi

mkdir "$APP_DIR"
cd "$APP_DIR"

echo -e "${PURPLE}📱 Step 1: Create Fresh Expo App${NC}"
echo "=================================="

# Create Expo app
npx create-expo-app@latest . --template blank-typescript

echo -e "${GREEN}✅ Expo app created${NC}"

echo -e "${PURPLE}📦 Step 2: Install Auction Dependencies${NC}"
echo "====================================="

# Install GraphQL and Apollo
npm install @apollo/client graphql

# Install navigation
npm install @react-navigation/native @react-navigation/stack @react-navigation/bottom-tabs

# Install Expo-specific dependencies
npx expo install react-native-screens react-native-safe-area-context
npx expo install react-native-gesture-handler react-native-reanimated
npx expo install @react-native-async-storage/async-storage

echo -e "${GREEN}✅ Dependencies installed${NC}"

echo -e "${PURPLE}🏗️ Step 3: Create Auction App Structure${NC}"
echo "========================================"

# Create directory structure
mkdir -p src/{services,screens,navigation}
mkdir -p src/screens/{auth,auctions,profile}
mkdir -p src/services/{auth,graphql}

echo -e "${YELLOW}Creating Apollo GraphQL client...${NC}"

# Apollo Client setup
cat > src/services/apollo.ts << 'EOF'
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import AsyncStorage from '@react-native-async-storage/async-storage';

// HTTP link to your Phase 1 GraphQL API
const httpLink = createHttpLink({
  uri: 'http://localhost:4000/graphql', // Your Phase 1 API Gateway
});

// Auth link to add JWT token to requests
const authLink = setContext(async (_, { headers }) => {
  const token = await AsyncStorage.getItem('authToken');
  
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  };
});

// Apollo Client instance
export const apolloClient = new ApolloClient({
  link: from([authLink, httpLink]),
  cache: new InMemoryCache({
    typePolicies: {
      Auction: {
        fields: {
          bids: {
            merge(existing = [], incoming) {
              return [...existing, ...incoming];
            },
          },
        },
      },
    },
  }),
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    },
  },
});
EOF

echo -e "${YELLOW}Creating authentication system...${NC}"

# Authentication Context
cat > src/services/auth/AuthContext.tsx << 'EOF'
import React, { createContext, useContext, useEffect, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
}

interface AuthContextType {
  user: User | null;
  token: string | null;
  login: (token: string, user: User) => Promise<void>;
  logout: () => Promise<void>;
  isLoading: boolean;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadAuthData();
  }, []);

  const loadAuthData = async () => {
    try {
      const savedToken = await AsyncStorage.getItem('authToken');
      const savedUser = await AsyncStorage.getItem('authUser');
      
      if (savedToken && savedUser) {
        setToken(savedToken);
        setUser(JSON.parse(savedUser));
      }
    } catch (error) {
      console.error('Error loading auth data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (newToken: string, newUser: User) => {
    try {
      await AsyncStorage.setItem('authToken', newToken);
      await AsyncStorage.setItem('authUser', JSON.stringify(newUser));
      setToken(newToken);
      setUser(newUser);
    } catch (error) {
      console.error('Error saving auth data:', error);
    }
  };

  const logout = async () => {
    try {
      await AsyncStorage.removeItem('authToken');
      await AsyncStorage.removeItem('authUser');
      setToken(null);
      setUser(null);
    } catch (error) {
      console.error('Error clearing auth data:', error);
    }
  };

  return (
    <AuthContext.Provider value={{ user, token, login, logout, isLoading }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
EOF

echo -e "${YELLOW}Creating GraphQL operations...${NC}"

# GraphQL Mutations
cat > src/services/graphql/mutations.ts << 'EOF'
import { gql } from '@apollo/client';

export const LOGIN_MUTATION = gql`
  mutation Login($input: LoginInput!) {
    login(input: $input) {
      token
      refreshToken
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

export const PLACE_BID_MUTATION = gql`
  mutation PlaceBid($auctionId: ID!, $amount: Float!) {
    placeBid(auctionId: $auctionId, amount: $amount) {
      bid {
        id
        amount
        timestamp
        bidder {
          firstName
        }
      }
      auction {
        id
        currentPrice
        bidCount
      }
    }
  }
`;
EOF

# GraphQL Queries
cat > src/services/graphql/queries.ts << 'EOF'
import { gql } from '@apollo/client';

export const GET_AUCTIONS = gql`
  query GetAuctions($filters: AuctionFilters, $pagination: PaginationInput) {
    auctions(filters: $filters, pagination: $pagination) {
      auctions {
        id
        title
        description
        images
        currentPrice
        startingPrice
        status
        endTime
        timeRemaining
        bidCount
        category {
          name
        }
        seller {
          firstName
          lastName
        }
      }
      totalCount
      hasMore
    }
  }
`;

export const GET_AUCTION_DETAIL = gql`
  query GetAuctionDetail($id: ID!) {
    auction(id: $id) {
      id
      title
      description
      images
      currentPrice
      startingPrice  
      reservePrice
      status
      startTime
      endTime
      timeRemaining
      bidCount
      watcherCount
      category {
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
        bidder {
          firstName
        }
      }
      highestBid {
        amount
        bidder {
          firstName
        }
      }
    }
  }
`;
EOF

echo -e "${YELLOW}Creating navigation system...${NC}"

# Navigation
cat > src/navigation/AppNavigator.tsx << 'EOF'
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { useAuth } from '../services/auth/AuthContext';

// Screens
import { LoadingScreen } from '../screens/LoadingScreen';
import { LoginScreen } from '../screens/auth/LoginScreen';
import { MainTabNavigator } from './MainTabNavigator';

const Stack = createStackNavigator();

export const AppNavigator: React.FC = () => {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return <LoadingScreen />;
  }

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {user ? (
          <Stack.Screen name="Main" component={MainTabNavigator} />
        ) : (
          <Stack.Screen name="Login" component={LoginScreen} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};
EOF

cat > src/navigation/MainTabNavigator.tsx << 'EOF'
import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';

// Screens
import { AuctionListScreen } from '../screens/auctions/AuctionListScreen';
import { AuctionDetailScreen } from '../screens/auctions/AuctionDetailScreen';
import { ProfileScreen } from '../screens/profile/ProfileScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

const AuctionStack = () => (
  <Stack.Navigator>
    <Stack.Screen 
      name="AuctionList" 
      component={AuctionListScreen} 
      options={{ title: '🏆 Live Auctions' }} 
    />
    <Stack.Screen 
      name="AuctionDetail" 
      component={AuctionDetailScreen} 
      options={{ title: '🎯 Auction Details' }} 
    />
  </Stack.Navigator>
);

export const MainTabNavigator: React.FC = () => {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: '#1a73e8',
        tabBarInactiveTintColor: 'gray',
        headerShown: false,
      }}>
      <Tab.Screen 
        name="Auctions" 
        component={AuctionStack}
        options={{
          tabBarLabel: 'Auctions',
          tabBarIcon: () => '🏆',
        }}
      />
      <Tab.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{
          tabBarLabel: 'Profile',
          tabBarIcon: () => '👤',
        }}
      />
    </Tab.Navigator>
  );
};
EOF

echo -e "${YELLOW}Creating mobile screens...${NC}"

# Loading Screen
cat > src/screens/LoadingScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';

export const LoadingScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>🏆 Auction Platform</Text>
      <ActivityIndicator size="large" color="#1a73e8" />
      <Text style={styles.text}>Loading your auction app...</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 20,
  },
  text: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
});
EOF

# Login Screen
cat > src/screens/auth/LoginScreen.tsx << 'EOF'
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useMutation } from '@apollo/client';
import { useAuth } from '../../services/auth/AuthContext';
import { LOGIN_MUTATION } from '../../services/graphql/mutations';

export const LoginScreen: React.FC = () => {
  const [email, setEmail] = useState('admin@auction.com');
  const [password, setPassword] = useState('password123');
  const [isLoading, setIsLoading] = useState(false);
  
  const { login } = useAuth();
  const [loginMutation] = useMutation(LOGIN_MUTATION);

  const handleLogin = async () => {
    if (!email || !password) {
      Alert.alert('Error', 'Please fill in all fields');
      return;
    }

    setIsLoading(true);
    try {
      const { data } = await loginMutation({
        variables: { input: { email, password } }
      });

      if (data?.login) {
        await login(data.login.token, data.login.user);
      }
    } catch (error: any) {
      Alert.alert('Login Failed', error.message || 'Make sure Phase 1 API is running:\ncd services/api-gateway && npm run dev');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <View style={styles.form}>
        <Text style={styles.title}>🏆 Auction Platform</Text>
        <Text style={styles.subtitle}>Mobile Demo App</Text>
        
        <View style={styles.infoBox}>
          <Text style={styles.infoTitle}>📱 Demo Ready!</Text>
          <Text style={styles.infoText}>✅ Real-time bidding</Text>
          <Text style={styles.infoText}>✅ Phase 1 API integration</Text>
          <Text style={styles.infoText}>✅ Cross-platform sync</Text>
        </View>
        
        <TextInput
          style={styles.input}
          placeholder="Email"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
        />
        
        <TextInput
          style={styles.input}
          placeholder="Password"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />
        
        <TouchableOpacity 
          style={[styles.button, isLoading && styles.buttonDisabled]}
          onPress={handleLogin}
          disabled={isLoading}
        >
          <Text style={styles.buttonText}>
            {isLoading ? '⏳ Connecting...' : '🚀 Login to Auction App'}
          </Text>
        </TouchableOpacity>
        
        <Text style={styles.footerText}>Demo credentials pre-filled!</Text>
        <Text style={styles.footerText}>Make sure your Phase 1 API is running</Text>
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  form: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
    color: '#1a73e8',
  },
  subtitle: {
    fontSize: 18,
    textAlign: 'center',
    marginBottom: 30,
    color: '#666',
  },
  infoBox: {
    backgroundColor: '#e3f2fd',
    padding: 20,
    borderRadius: 12,
    marginBottom: 30,
    alignItems: 'center',
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 8,
  },
  infoText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 4,
  },
  input: {
    backgroundColor: '#fff',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    marginBottom: 16,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  button: {
    backgroundColor: '#1a73e8',
    borderRadius: 8,
    paddingVertical: 15,
    marginTop: 16,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  footerText: {
    color: '#666',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 8,
    fontStyle: 'italic',
  },
});
EOF

# Auction List Screen
cat > src/screens/auctions/AuctionListScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, FlatList, Alert, RefreshControl } from 'react-native';
import { useQuery } from '@apollo/client';
import { GET_AUCTIONS } from '../../services/graphql/queries';

export const AuctionListScreen: React.FC = ({ navigation }: any) => {
  const { data, loading, error, refetch } = useQuery(GET_AUCTIONS, {
    variables: {
      filters: { status: 'ACTIVE' },
      pagination: { limit: 20, offset: 0 }
    },
    pollInterval: 5000, // Real-time updates every 5 seconds
  });

  const handleAuctionPress = (item: any) => {
    navigation.navigate('AuctionDetail', { auctionId: item.id });
  };

  const renderAuction = ({ item }: any) => (
    <TouchableOpacity
      style={styles.auctionCard}
      onPress={() => handleAuctionPress(item)}
    >
      <View style={styles.cardHeader}>
        <Text style={styles.title} numberOfLines={2}>{item.title}</Text>
        <Text style={styles.status}>🔴 LIVE</Text>
      </View>
      
      <Text style={styles.price}>💰 ${item.currentPrice.toLocaleString()}</Text>
      
      <View style={styles.cardFooter}>
        <Text style={styles.bids}>📈 {item.bidCount} bids</Text>
        <Text style={styles.category}>📂 {item.category.name}</Text>
      </View>
      
      <Text style={styles.seller}>👤 {item.seller.firstName} {item.seller.lastName}</Text>
      
      <View style={styles.tapHint}>
        <Text style={styles.tapText}>👆 Tap to bid</Text>
      </View>
    </TouchableOpacity>
  );

  if (loading && !data) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingTitle}>📱 Loading Live Auctions</Text>
        <Text style={styles.loadingText}>Connecting to Phase 1 API...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorTitle}>🔌 Connection Error</Text>
        <Text style={styles.errorText}>Cannot connect to Phase 1 API</Text>
        <Text style={styles.errorDetail}>Make sure your API is running:</Text>
        <Text style={styles.errorCode}>cd services/api-gateway</Text>
        <Text style={styles.errorCode}>npm run dev</Text>
        <TouchableOpacity style={styles.retryButton} onPress={() => refetch()}>
          <Text style={styles.retryText}>🔄 Retry Connection</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const auctions = data?.auctions?.auctions || [];

  return (
    <View style={styles.container}>
      <FlatList
        data={auctions}
        renderItem={renderAuction}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContainer}
        refreshControl={
          <RefreshControl refreshing={loading} onRefresh={refetch} />
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyTitle}>🎯 No Active Auctions</Text>
            <Text style={styles.emptyText}>Start your Phase 1 API to see live auctions</Text>
          </View>
        }
        ListHeaderComponent={
          <View style={styles.header}>
            <Text style={styles.headerTitle}>🏆 Live Auctions</Text>
            <Text style={styles.headerSubtitle}>Updates every 5 seconds • Tap to bid</Text>
          </View>
        }
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    backgroundColor: '#1a73e8',
    padding: 20,
    borderRadius: 12,
    marginBottom: 20,
    alignItems: 'center',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#e3f2fd',
    marginTop: 4,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
    paddingHorizontal: 20,
  },
  listContainer: {
    padding: 16,
  },
  auctionCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderLeftWidth: 4,
    borderLeftColor: '#1a73e8',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    flex: 1,
    marginRight: 8,
  },
  status: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#ff4444',
  },
  price: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 12,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  bids: {
    fontSize: 14,
    color: '#666',
  },
  category: {
    fontSize: 14,
    color: '#666',
  },
  seller: {
    fontSize: 12,
    color: '#999',
    marginBottom: 8,
  },
  tapHint: {
    backgroundColor: '#e3f2fd',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    alignSelf: 'center',
  },
  tapText: {
    fontSize: 12,
    color: '#1a73e8',
    fontWeight: 'bold',
  },
  loadingTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#ff4444',
    marginBottom: 8,
  },
  errorText: {
    fontSize: 16,
    color: '#666',
    marginBottom: 8,
    textAlign: 'center',
  },
  errorDetail: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
    textAlign: 'center',
  },
  errorCode: {
    fontSize: 12,
    color: '#333',
    fontFamily: 'monospace',
    backgroundColor: '#f0f0f0',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    marginBottom: 4,
  },
  retryButton: {
    backgroundColor: '#1a73e8',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: 16,
  },
  retryText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  emptyContainer: {
    alignItems: 'center',
    marginTop: 50,
  },
  emptyTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  emptyText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
});
EOF

# Auction Detail Screen
cat > src/screens/auctions/AuctionDetailScreen.tsx << 'EOF'
import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, Alert, ScrollView } from 'react-native';
import { useQuery, useMutation } from '@apollo/client';
import { GET_AUCTION_DETAIL } from '../../services/graphql/queries';
import { PLACE_BID_MUTATION } from '../../services/graphql/mutations';

export const AuctionDetailScreen: React.FC = ({ route }: any) => {
  const { auctionId } = route.params;
  const [bidAmount, setBidAmount] = useState('');
  const [isPlacingBid, setIsPlacingBid] = useState(false);

  const { data, loading, error, refetch } = useQuery(GET_AUCTION_DETAIL, {
    variables: { id: auctionId },
    pollInterval: 2000, // Real-time updates every 2 seconds
  });

  const [placeBid] = useMutation(PLACE_BID_MUTATION, {
    onCompleted: () => {
      setBidAmount('');
      Alert.alert('🎉 Bid Placed!', 'Your bid has been successfully placed!');
      refetch();
    },
    onError: (error) => {
      Alert.alert('❌ Bid Failed', error.message);
    },
  });

  const auction = data?.auction;
  const minBidAmount = auction ? auction.currentPrice + 1 : 0;

  const handlePlaceBid = async () => {
    const amount = parseFloat(bidAmount);
    
    if (!amount || amount < minBidAmount) {
      Alert.alert(
        '⚠️ Invalid Bid', 
        `Minimum bid is $${minBidAmount.toLocaleString()}`
      );
      return;
    }

    setIsPlacingBid(true);
    try {
      await placeBid({
        variables: { auctionId, amount },
      });
    } finally {
      setIsPlacingBid(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingText}>📱 Loading auction details...</Text>
      </View>
    );
  }

  if (error || !auction) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>❌ Auction not found</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>{auction.title}</Text>
        <Text style={styles.status}>🔴 LIVE AUCTION</Text>
      </View>

      <View style={styles.priceSection}>
        <Text style={styles.priceLabel}>💰 Current Bid</Text>
        <Text style={styles.currentPrice}>${auction.currentPrice.toLocaleString()}</Text>
        <View style={styles.stats}>
          <Text style={styles.statText}>📈 {auction.bidCount} bids</Text>
          <Text style={styles.statText}>👀 {auction.watcherCount} watching</Text>
        </View>
      </View>

      <View style={styles.descriptionSection}>
        <Text style={styles.sectionTitle}>📝 Description</Text>
        <Text style={styles.description}>{auction.description}</Text>
      </View>

      {auction.status === 'ACTIVE' && (
        <View style={styles.biddingSection}>
          <Text style={styles.biddingTitle}>🎯 Place Your Bid</Text>
          
          <View style={styles.bidInputContainer}>
            <Text style={styles.dollarSign}>$</Text>
            <TextInput
              style={styles.bidInput}
              value={bidAmount}
              onChangeText={setBidAmount}
              placeholder={minBidAmount.toString()}
              keyboardType="numeric"
              editable={!isPlacingBid}
            />
          </View>
          
          <TouchableOpacity
            style={[styles.bidButton, isPlacingBid && styles.bidButtonDisabled]}
            onPress={handlePlaceBid}
            disabled={isPlacingBid}
          >
            <Text style={styles.bidButtonText}>
              {isPlacingBid ? '⏳ Placing Bid...' : '🚀 Place Bid'}
            </Text>
          </TouchableOpacity>
          
          <Text style={styles.minBidText}>
            Minimum bid: ${minBidAmount.toLocaleString()}
          </Text>
        </View>
      )}

      <View style={styles.bidsSection}>
        <Text style={styles.sectionTitle}>📊 Recent Bids</Text>
        {auction.bids.slice(0, 5).map((bid: any, index: number) => (
          <View key={bid.id} style={styles.bidItem}>
            <Text style={styles.bidAmount}>${bid.amount.toLocaleString()}</Text>
            <Text style={styles.bidder}>👤 {bid.bidder.firstName}</Text>
            <Text style={styles.bidTime}>
              {new Date(bid.timestamp).toLocaleTimeString()}
            </Text>
          </View>
        ))}
        {auction.bids.length === 0 && (
          <Text style={styles.noBids}>No bids yet. Be the first to bid!</Text>
        )}
      </View>

      <View style={styles.sellerSection}>
        <Text style={styles.sectionTitle}>👨‍💼 Seller</Text>
        <Text style={styles.sellerName}>
          {auction.seller.firstName} {auction.seller.lastName}
        </Text>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
  },
  header: {
    backgroundColor: '#fff',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  status: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#ff4444',
  },
  priceSection: {
    backgroundColor: '#fff',
    padding: 20,
    marginTop: 10,
    alignItems: 'center',
  },
  priceLabel: {
    fontSize: 16,
    color: '#666',
    marginBottom: 8,
  },
  currentPrice: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 12,
  },
  stats: {
    flexDirection: 'row',
    gap: 20,
  },
  statText: {
    fontSize: 14,
    color: '#666',
  },
  descriptionSection: {
    backgroundColor: '#fff',
    padding: 20,
    marginTop: 10,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  description: {
    fontSize: 16,
    color: '#666',
    lineHeight: 24,
  },
  biddingSection: {
    backgroundColor: '#e3f2fd',
    margin: 10,
    padding: 20,
    borderRadius: 12,
    alignItems: 'center',
  },
  biddingTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 16,
  },
  bidInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  dollarSign: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginRight: 12,
  },
  bidInput: {
    backgroundColor: '#fff',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 20,
    fontWeight: 'bold',
    borderWidth: 1,
    borderColor: '#ddd',
    minWidth: 150,
    textAlign: 'center',
  },
  bidButton: {
    backgroundColor: '#1a73e8',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 8,
    marginBottom: 8,
  },
  bidButtonDisabled: {
    opacity: 0.6,
  },
  bidButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  minBidText: {
    fontSize: 12,
    color: '#666',
  },
  bidsSection: {
    backgroundColor: '#fff',
    padding: 20,
    marginTop: 10,
  },
  bidItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  bidAmount: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1a73e8',
    flex: 1,
  },
  bidder: {
    fontSize: 14,
    color: '#333',
    flex: 1,
    textAlign: 'center',
  },
  bidTime: {
    fontSize: 12,
    color: '#666',
    flex: 1,
    textAlign: 'right',
  },
  noBids: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    fontStyle: 'italic',
  },
  sellerSection: {
    backgroundColor: '#fff',
    padding: 20,
    marginTop: 10,
    marginBottom: 20,
  },
  sellerName: {
    fontSize: 16,
    color: '#333',
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  errorText: {
    fontSize: 16,
    color: '#ff4444',
    textAlign: 'center',
  },
});
EOF

# Profile Screen
cat > src/screens/profile/ProfileScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { useAuth } from '../../services/auth/AuthContext';

export const ProfileScreen: React.FC = () => {
  const { user, logout } = useAuth();

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>👤 Profile</Text>
      </View>
      
      <View style={styles.userCard}>
        <Text style={styles.userName}>{user?.firstName} {user?.lastName}</Text>
        <Text style={styles.userEmail}>{user?.email}</Text>
        <Text style={styles.userRole}>Role: {user?.role}</Text>
      </View>
      
      <View style={styles.appInfo}>
        <Text style={styles.appTitle}>📱 Mobile Demo App</Text>
        <Text style={styles.appFeature}>✅ Real-time GraphQL integration</Text>
        <Text style={styles.appFeature}>✅ Cross-platform bidding</Text>
        <Text style={styles.appFeature}>✅ Live auction updates</Text>
        <Text style={styles.appFeature}>✅ Professional mobile UI</Text>
        <Text style={styles.appFeature}>✅ Perfect for job interviews!</Text>
      </View>
      
      <View style={styles.instructions}>
        <Text style={styles.instructionsTitle}>🚀 Demo Instructions</Text>
        <Text style={styles.instructionText}>1. Make sure Phase 1 API is running</Text>
        <Text style={styles.instructionText}>2. Browse live auctions in real-time</Text>
        <Text style={styles.instructionText}>3. Place bids and see instant updates</Text>
        <Text style={styles.instructionText}>4. Show cross-platform sync with web!</Text>
      </View>
      
      <TouchableOpacity style={styles.logoutButton} onPress={logout}>
        <Text style={styles.logoutText}>🚪 Logout</Text>
      </TouchableOpacity>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    backgroundColor: '#1a73e8',
    padding: 20,
    paddingTop: 60,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    textAlign: 'center',
  },
  userCard: {
    backgroundColor: '#fff',
    margin: 20,
    padding: 20,
    borderRadius: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  userName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  userEmail: {
    fontSize: 16,
    color: '#666',
    marginBottom: 8,
  },
  userRole: {
    fontSize: 14,
    color: '#1a73e8',
    fontWeight: 'bold',
  },
  appInfo: {
    backgroundColor: '#e3f2fd',
    margin: 20,
    padding: 20,
    borderRadius: 12,
  },
  appTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 12,
    textAlign: 'center',
  },
  appFeature: {
    fontSize: 14,
    color: '#666',
    marginBottom: 6,
    textAlign: 'center',
  },
  instructions: {
    backgroundColor: '#fff',
    margin: 20,
    padding: 20,
    borderRadius: 12,
  },
  instructionsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  instructionText: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  logoutButton: {
    backgroundColor: '#ff4444',
    margin: 20,
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 40,
  },
  logoutText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
});
EOF

echo -e "${YELLOW}Updating main App.tsx...${NC}"

# Update main App.tsx
cat > App.tsx << 'EOF'
import React from 'react';
import { ApolloProvider } from '@apollo/client';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

import { apolloClient } from './src/services/apollo';
import { AppNavigator } from './src/navigation/AppNavigator';
import { AuthProvider } from './src/services/auth/AuthContext';

export default function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <SafeAreaProvider>
        <AuthProvider>
          <AppNavigator />
          <StatusBar style="auto" />
        </AuthProvider>
      </SafeAreaProvider>
    </ApolloProvider>
  );
}
EOF

echo -e "${GREEN}✅ Auction app structure complete${NC}"

echo -e "${PURPLE}🧪 Step 4: Create Demo Test Script${NC}"
echo "=================================="

# Create test script
cat > test-demo.sh << 'EOF'
#!/bin/bash

echo "🧪 TESTING STANDALONE AUCTION DEMO"
echo "=================================="

echo "📱 Project structure:"
if [ -f "App.tsx" ] && [ -d "src" ]; then
    echo "✅ App structure: READY"
else
    echo "❌ App structure: FAILED"
fi

echo "📦 Dependencies:"
if grep -q "@apollo/client" package.json; then
    echo "✅ GraphQL: READY"
else
    echo "❌ GraphQL: FAILED"
fi

echo "🔗 Phase 1 API connection:"
if curl -s http://localhost:4000/health > /dev/null 2>&1; then
    echo "✅ Phase 1 API: RUNNING"
else
    echo "⚠️  Phase 1 API: NOT RUNNING"
    echo "   Start with: cd services/api-gateway && npm run dev"
fi

echo ""
echo "🚀 Ready to demo!"
echo "1. npx expo start"
echo "2. Scan QR code with Expo Go app"
echo "3. Login and test real-time bidding!"
EOF

chmod +x test-demo.sh

echo -e "${GREEN}✅ Test script created${NC}"
echo ""

echo -e "${CYAN}🎉 STANDALONE AUCTION DEMO READY!${NC}"
echo "================================="
echo ""
echo -e "${BLUE}📁 Location: ~/Desktop/auction-mobile-demo${NC}"
echo ""
echo -e "${PURPLE}🚀 NEXT STEPS:${NC}"
echo "=============="
echo ""
echo "1. Test the setup:"
echo "   ./test-demo.sh"
echo ""
echo "2. Start your Phase 1 API (in your main project):"
echo "   cd services/api-gateway"
echo "   npm run dev"
echo ""
echo "3. Start the mobile demo:"
echo "   npx expo start"
echo ""
echo "4. Install Expo Go on your phone and scan QR code!"
echo ""
echo -e "${GREEN}🔥 DEMO FEATURES:${NC}"
echo "================="
echo "   📱 Professional mobile auction app"
echo "   🔄 Real-time bidding with Phase 1 API"
echo "   🎯 Cross-platform sync (mobile + web)"
echo "   ✨ Perfect for job interview demos"
echo "   🚀 No Xcode/Android Studio needed"
echo ""
echo -e "${BLUE}📱 Download Expo Go:${NC}"
echo "   iOS: App Store → 'Expo Go'"
echo "   Android: Play Store → 'Expo Go'"
echo ""
echo -e "${CYAN}Your standalone auction demo is ready! 🎉📱${NC}"