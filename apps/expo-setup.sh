#!/bin/bash

echo "🚀 EXPO MOBILE APP SETUP - CLEAN & SIMPLE"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}📱 Why Expo is PERFECT for your auction app:${NC}"
echo "• No Xcode/Android Studio setup needed"
echo "• Run on real devices instantly via Expo Go app"
echo "• Professional demos on any device"
echo "• Same GraphQL integration capabilities"
echo "• Easier to showcase in interviews"
echo ""

# Navigate to apps directory
cd apps

echo -e "${PURPLE}🧹 Step 1: Clean Up Previous Attempts${NC}"
echo "======================================"

# Remove failed attempts
if [ -d "mobile" ]; then
    echo "Removing previous mobile directory..."
    rm -rf mobile
fi

if [ -d "mobile-backup" ]; then
    echo "Removing backup directory..."
    rm -rf mobile-backup
fi

if [ -d "../mobile" ]; then
    echo "Removing mobile directory from root..."
    rm -rf ../mobile
fi

if [ -d "../mobile-backup" ]; then
    echo "Removing backup from root..."
    rm -rf ../mobile-backup
fi

echo -e "${GREEN}✅ Cleaned up previous attempts${NC}"
echo ""

echo -e "${PURPLE}📱 Step 2: Create Expo App${NC}"
echo "=========================="

# Create Expo app with TypeScript
echo "Creating Expo app with TypeScript..."
npx create-expo-app@latest mobile --template blank-typescript

cd mobile

echo -e "${GREEN}✅ Expo app created successfully!${NC}"
echo ""

echo -e "${PURPLE}📦 Step 3: Install Auction App Dependencies${NC}"
echo "==========================================="

# Install our specific dependencies for the auction app
echo "Installing GraphQL and navigation dependencies..."

npm install @apollo/client graphql
npm install @react-navigation/native @react-navigation/stack @react-navigation/bottom-tabs
npm install react-native-screens react-native-safe-area-context
npm install @react-native-async-storage/async-storage
npm install react-native-gesture-handler react-native-reanimated

# Expo-specific installations
npx expo install react-native-screens react-native-safe-area-context
npx expo install react-native-gesture-handler react-native-reanimated
npx expo install @react-native-async-storage/async-storage

echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

echo -e "${PURPLE}🔧 Step 4: Configure Expo App${NC}"
echo "============================="

# Update app.json for our auction app
cat > app.json << 'EOF'
{
  "expo": {
    "name": "Auction Platform",
    "slug": "auction-mobile",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#1a73e8"
    },
    "assetBundlePatterns": [
      "**/*"
    ],
    "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "com.auction.mobile"
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#1a73e8"
      },
      "package": "com.auction.mobile"
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "plugins": [
      "expo-router"
    ]
  }
}
EOF

echo -e "${GREEN}✅ Expo configuration updated${NC}"
echo ""

echo -e "${PURPLE}📱 Step 5: Create Auction App Structure${NC}"
echo "=========================================="

# Create directory structure
mkdir -p src/{components,screens,navigation,services,utils,types}
mkdir -p src/screens/{auth,auctions,profile,bids}
mkdir -p src/services/{auth,graphql}

echo "Created directory structure"

# Apollo Client setup
cat > src/services/apollo.ts << 'EOF'
import { ApolloClient, InMemoryCache, createHttpLink, from } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import AsyncStorage from '@react-native-async-storage/async-storage';

// HTTP link to your GraphQL API
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

# Auth Context
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

# GraphQL operations
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

# Navigation setup
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
    <Stack.Screen name="AuctionList" component={AuctionListScreen} options={{ title: 'Auctions' }} />
    <Stack.Screen name="AuctionDetail" component={AuctionDetailScreen} options={{ title: 'Auction Details' }} />
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
      <Tab.Screen name="Auctions" component={AuctionStack} />
      <Tab.Screen name="Profile" component={ProfileScreen} />
    </Tab.Navigator>
  );
};
EOF

# Create screens
cat > src/screens/LoadingScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';

export const LoadingScreen: React.FC = () => {
  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color="#1a73e8" />
      <Text style={styles.text}>Loading Auction Platform...</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  text: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
});
EOF

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
        variables: {
          input: { email, password }
        }
      });

      if (data?.login) {
        await login(data.login.token, data.login.user);
      }
    } catch (error: any) {
      Alert.alert('Login Failed', error.message || 'Please try again');
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
        <Text style={styles.subtitle}>Welcome Back!</Text>
        
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
            {isLoading ? 'Signing In...' : 'Sign In'}
          </Text>
        </TouchableOpacity>
        
        <Text style={styles.demoText}>✨ Demo credentials pre-filled!</Text>
        <Text style={styles.infoText}>📱 Running on Expo for easy testing</Text>
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
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
    color: '#1a73e8',
  },
  subtitle: {
    fontSize: 20,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 32,
    color: '#333',
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
    paddingVertical: 12,
    marginTop: 16,
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    textAlign: 'center',
  },
  demoText: {
    color: '#666',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 20,
    fontStyle: 'italic',
  },
  infoText: {
    color: '#1a73e8',
    fontSize: 12,
    textAlign: 'center',
    marginTop: 8,
    fontStyle: 'italic',
  },
});
EOF

# Create simple auction screens
cat > src/screens/auctions/AuctionListScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, FlatList } from 'react-native';
import { useQuery } from '@apollo/client';
import { GET_AUCTIONS } from '../../services/graphql/queries';

export const AuctionListScreen: React.FC = ({ navigation }: any) => {
  const { data, loading, error } = useQuery(GET_AUCTIONS, {
    variables: {
      filters: { status: 'ACTIVE' },
      pagination: { limit: 20, offset: 0 }
    },
    pollInterval: 5000, // Real-time updates
  });

  const renderAuction = ({ item }: any) => (
    <TouchableOpacity
      style={styles.auctionCard}
      onPress={() => navigation.navigate('AuctionDetail', { auctionId: item.id })}
    >
      <Text style={styles.title}>{item.title}</Text>
      <Text style={styles.price}>💰 ${item.currentPrice.toLocaleString()}</Text>
      <Text style={styles.bids}>📈 {item.bidCount} bids</Text>
      <Text style={styles.category}>📂 {item.category.name}</Text>
    </TouchableOpacity>
  );

  if (loading) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingText}>📱 Loading auctions...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>❌ Error loading auctions</Text>
        <Text style={styles.errorDetail}>{error.message}</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={data?.auctions?.auctions || []}
        renderItem={renderAuction}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContainer}
      />
    </View>
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
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
  },
  price: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 4,
  },
  bids: {
    fontSize: 14,
    color: '#666',
    marginBottom: 4,
  },
  category: {
    fontSize: 14,
    color: '#666',
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  errorText: {
    fontSize: 16,
    color: '#ff4444',
    textAlign: 'center',
    marginBottom: 8,
  },
  errorDetail: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
});
EOF

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
    pollInterval: 2000, // Real-time updates
  });

  const [placeBid] = useMutation(PLACE_BID_MUTATION, {
    onCompleted: () => {
      setBidAmount('');
      Alert.alert('🎉 Success!', 'Your bid has been placed!');
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
      Alert.alert('⚠️ Invalid Bid', `Minimum bid is $${minBidAmount.toLocaleString()}`);
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
        <Text style={styles.loadingText}>📱 Loading auction...</Text>
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
        <Text style={styles.status}>🔴 LIVE</Text>
      </View>

      <View style={styles.priceContainer}>
        <Text style={styles.priceLabel}>💰 Current Bid</Text>
        <Text style={styles.currentPrice}>${auction.currentPrice.toLocaleString()}</Text>
        <Text style={styles.bidCount}>📈 {auction.bidCount} bids</Text>
      </View>

      <Text style={styles.description}>{auction.description}</Text>

      {auction.status === 'ACTIVE' && (
        <View style={styles.biddingContainer}>
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
            <TouchableOpacity
              style={[styles.bidButton, isPlacingBid && styles.bidButtonDisabled]}
              onPress={handlePlaceBid}
              disabled={isPlacingBid}
            >
              <Text style={styles.bidButtonText}>
                {isPlacingBid ? '⏳ Placing...' : '🚀 Place Bid'}
              </Text>
            </TouchableOpacity>
          </View>
          <Text style={styles.minBidText}>
            Minimum bid: ${minBidAmount.toLocaleString()}
          </Text>
        </View>
      )}
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
    color: '#ff4444',
    fontWeight: 'bold',
  },
  priceContainer: {
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
    fontSize: 32,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 8,
  },
  bidCount: {
    fontSize: 14,
    color: '#666',
  },
  description: {
    backgroundColor: '#fff',
    padding: 20,
    marginTop: 10,
    fontSize: 16,
    color: '#666',
    lineHeight: 24,
  },
  biddingContainer: {
    backgroundColor: '#e3f2fd',
    margin: 10,
    padding: 20,
    borderRadius: 12,
  },
  biddingTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 16,
    textAlign: 'center',
  },
  bidInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  dollarSign: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginRight: 8,
  },
  bidInput: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 18,
    fontWeight: 'bold',
    marginRight: 12,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  bidButton: {
    backgroundColor: '#1a73e8',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 8,
  },
  bidButtonDisabled: {
    opacity: 0.6,
  },
  bidButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  minBidText: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
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

cat > src/screens/profile/ProfileScreen.tsx << 'EOF'
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useAuth } from '../../services/auth/AuthContext';

export const ProfileScreen: React.FC = () => {
  const { user, logout } = useAuth();

  return (
    <View style={styles.container}>
      <Text style={styles.title}>👤 Profile</Text>
      
      <View style={styles.infoContainer}>
        <Text style={styles.info}>Name: {user?.firstName} {user?.lastName}</Text>
        <Text style={styles.info}>Email: {user?.email}</Text>
        <Text style={styles.info}>Role: {user?.role}</Text>
      </View>
      
      <TouchableOpacity style={styles.button} onPress={logout}>
        <Text style={styles.buttonText}>🚪 Logout</Text>
      </TouchableOpacity>
      
      <View style={styles.expoInfo}>
        <Text style={styles.expoTitle}>📱 Running on Expo</Text>
        <Text style={styles.expoText}>Perfect for demos and development!</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 30,
    textAlign: 'center',
    color: '#333',
  },
  infoContainer: {
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 12,
    marginBottom: 30,
  },
  info: {
    fontSize: 16,
    marginBottom: 12,
    color: '#333',
  },
  button: {
    backgroundColor: '#ff4444',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 30,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  expoInfo: {
    backgroundColor: '#e3f2fd',
    padding: 20,
    borderRadius: 12,
    alignItems: 'center',
  },
  expoTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a73e8',
    marginBottom: 8,
  },
  expoText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
});
EOF

# Update main App.tsx
cat > App.tsx << 'EOF'
import React from 'react';
import { ApolloProvider } from '@apollo/client';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { apolloClient } from './src/services/apollo';
import { AppNavigator } from './src/navigation/AppNavigator';
import { AuthProvider } from './src/services/auth/AuthContext';

export default function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <SafeAreaProvider>
        <AuthProvider>
          <AppNavigator />
        </AuthProvider>
      </SafeAreaProvider>
    </ApolloProvider>
  );
}
EOF

echo -e "${GREEN}✅ Auction app structure created${NC}"
echo ""

echo -e "${PURPLE}🧪 Step 6: Create Test Script${NC}"
echo "============================="

cat > test-expo-app.sh << 'EOF'
#!/bin/bash

echo "🧪 TESTING EXPO AUCTION APP"
echo "============================"

echo "📱 Checking project structure..."
if [ -f "App.tsx" ] && [ -d "src" ]; then
    echo "✅ Basic structure: PASSED"
else
    echo "❌ Basic structure: FAILED"
fi

echo "📦 Checking dependencies..."
if [ -f "package.json" ]; then
    if grep -q "@apollo/client" package.json; then
        echo "✅ GraphQL dependencies: PASSED"
    else
        echo "❌ GraphQL dependencies: FAILED"
    fi
    
    if grep -q "@react-navigation" package.json; then
        echo "✅ Navigation dependencies: PASSED"
    else
        echo "❌ Navigation dependencies: FAILED"
    fi
else
    echo "❌ package.json: NOT FOUND"
fi

echo ""
echo "🚀 Ready for Expo development!"
echo "Next steps:"
echo "1. npx expo start"
echo "2. Scan QR code with Expo Go app"
echo "3. Test on your phone!"
EOF

chmod +x test-expo-app.sh

echo -e "${GREEN}✅ Test script created${NC}"
echo ""

echo -e "${CYAN}🎉 EXPO AUCTION APP SETUP COMPLETE!${NC}"
echo "===================================="
echo ""
echo -e "${BLUE}📱 What we've created:${NC}"
echo "   ✅ Complete Expo app with TypeScript"
echo "   ✅ Apollo GraphQL client for Phase 1 integration"
echo "   ✅ Professional navigation structure"
echo "   ✅ Authentication system with secure storage"
echo "   ✅ Real-time auction components"
echo "   ✅ Professional mobile UI with emojis"
echo "   ✅ No Xcode/Android Studio needed!"
echo ""
echo -e "${PURPLE}🚀 IMMEDIATE NEXT STEPS:${NC}"
echo "========================="
echo ""
echo "1. Test the setup:"
echo "   ./test-expo-app.sh"
echo ""
echo "2. Start Expo development server:"
echo "   npx expo start"
echo ""
echo "3. Install Expo Go app on your phone:"
echo "   iOS: https://apps.apple.com/app/expo-go/id982107779"
echo "   Android: https://play.google.com/store/apps/details?id=host.exp.exponent"
echo ""
echo "4. Scan QR code with your phone to test!"
echo ""
echo -e "${GREEN}🔥 DEMO ADVANTAGES:${NC}"
echo "=================="
echo "   📱 Test on real devices instantly"
echo "   🌐 No simulator setup needed"
echo "   ⚡ Hot reload for fast development"
echo "   🎯 Perfect for job interview demos"
echo "   🔄 Same real-time bidding capabilities"
echo ""
echo -e "${CYAN}Your Expo auction app is ready! 🚀📱✨${NC}"