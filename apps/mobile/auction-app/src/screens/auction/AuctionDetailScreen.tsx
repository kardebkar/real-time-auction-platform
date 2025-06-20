import React, { useState } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TextInput,
  Alert,
  RefreshControl,
} from 'react-native';
import { useQuery, useMutation } from '@apollo/client';
import { GET_AUCTION_DETAIL, PLACE_BID_MUTATION } from '../../services/apollo/queries';
import { Button } from '../../components/common/Button';
import { COLORS, SPACING, TYPOGRAPHY } from '../../utils/constants';

interface AuctionDetailScreenProps {
  route: {
    params: {
      auctionId: string;
    };
  };
  navigation: any;
}

export const AuctionDetailScreen: React.FC<AuctionDetailScreenProps> = ({ route, navigation }) => {
  const { auctionId } = route.params;
  const [bidAmount, setBidAmount] = useState('');
  
  const { data, loading, error, refetch } = useQuery(GET_AUCTION_DETAIL, {
    variables: { id: auctionId },
    pollInterval: 3000, // Real-time updates every 3 seconds
  });

  const [placeBid, { loading: bidLoading }] = useMutation(PLACE_BID_MUTATION, {
    refetchQueries: [{ query: GET_AUCTION_DETAIL, variables: { id: auctionId } }],
  });

  const auction = data?.auction;

  const handlePlaceBid = async () => {
    const amount = parseFloat(bidAmount);
    
    if (!amount || amount <= auction?.currentPrice) {
      Alert.alert('Invalid Bid', `Bid must be higher than current price (${auction?.currentPrice})`);
      return;
    }

    try {
      await placeBid({
        variables: {
          input: {
            auctionId,
            amount,
          }
        },
      });
      
      setBidAmount('');
      Alert.alert('Success! 🎉', 'Your bid has been placed successfully!');
    } catch (error: any) {
      Alert.alert('Bidding Error', error.message || 'Failed to place bid');
    }
  };

  const formatTimeRemaining = (endTime: string) => {
    const end = new Date(endTime);
    const now = new Date();
    const diff = end.getTime() - now.getTime();
    
    if (diff <= 0) return 'Auction ended';
    
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    
    if (days > 0) return `${days}d ${hours}h ${minutes}m`;
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'ACTIVE': return COLORS.secondary;
      case 'SCHEDULED': return COLORS.warning;
      case 'DRAFT': return COLORS.textSecondary;
      default: return COLORS.error;
    }
  };

  if (loading && !data) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingText}>📱 Loading auction details...</Text>
      </View>
    );
  }

  if (error || !auction) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>❌ Error loading auction</Text>
        <Button title="Go Back" onPress={() => navigation.goBack()} />
      </View>
    );
  }

  return (
    <ScrollView 
      style={styles.container}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} />}
    >
      {/* Header Card */}
      <View style={styles.card}>
        <View style={styles.header}>
          <Text style={styles.title}>{auction.title}</Text>
          <View style={[styles.statusBadge, { backgroundColor: getStatusColor(auction.status) }]}>
            <Text style={styles.statusText}>{auction.status}</Text>
          </View>
        </View>
        
        <Text style={styles.description}>{auction.description}</Text>
        
        <View style={styles.priceSection}>
          <View style={styles.priceRow}>
            <Text style={styles.priceLabel}>💰 Current Price:</Text>
            <Text style={styles.currentPrice}>
              ${auction.currentPrice.toLocaleString()}
            </Text>
          </View>
          <View style={styles.priceRow}>
            <Text style={styles.priceLabel}>🏁 Starting Price:</Text>
            <Text style={styles.startingPrice}>
              ${auction.startingPrice.toLocaleString()}
            </Text>
          </View>
          <View style={styles.priceRow}>
            <Text style={styles.priceLabel}>📈 Total Bids:</Text>
            <Text style={styles.bidCount}>{auction.bidCount}</Text>
          </View>
        </View>

        {auction.endTime && (
          <View style={styles.timeSection}>
            <Text style={styles.timeLabel}>⏰ Time Remaining:</Text>
            <Text style={styles.timeRemaining}>
              {formatTimeRemaining(auction.endTime)}
            </Text>
          </View>
        )}

        <View style={styles.metaSection}>
          <Text style={styles.metaText}>📂 {auction.category?.name || 'No Category'}</Text>
          <Text style={styles.metaText}>
            👤 {auction.seller?.firstName} {auction.seller?.lastName}
          </Text>
        </View>
      </View>

      {/* Bidding Section */}
      {auction.status === 'ACTIVE' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>🎯 Place Your Bid</Text>
          <Text style={styles.bidHint}>
            Minimum bid: ${(auction.currentPrice + 1).toLocaleString()}
          </Text>
          
          <TextInput
            style={styles.bidInput}
            value={bidAmount}
            onChangeText={setBidAmount}
            placeholder={`Enter amount (min ${auction.currentPrice + 1})`}
            keyboardType="numeric"
          />
          
          <Button
            title="🔥 Place Bid"
            onPress={handlePlaceBid}
            loading={bidLoading}
            disabled={!bidAmount}
          />
        </View>
      )}

      {/* Quick Bid Buttons for ACTIVE auctions */}
      {auction.status === 'ACTIVE' && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>⚡ Quick Bid</Text>
          <View style={styles.quickBidContainer}>
            {[1, 5, 10, 25].map((increment) => {
              const quickBidAmount = auction.currentPrice + increment;
              return (
                <Button
                  key={increment}
                  title={`+${increment}`}
                  onPress={() => setBidAmount(quickBidAmount.toString())}
                  variant="secondary"
                  style={styles.quickBidButton}
                />
              );
            })}
          </View>
        </View>
      )}

      {/* Recent Bids Section */}
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>📈 Recent Bids</Text>
        {auction.bids && auction.bids.length > 0 ? (
          auction.bids.slice(0, 10).map((bid: any, index: number) => (
            <View key={bid.id || index} style={styles.bidItem}>
              <View style={styles.bidInfo}>
                <Text style={styles.bidder}>
                  {bid.user?.firstName} {bid.user?.lastName}
                </Text>
                <Text style={styles.bidTime}>
                  {bid.timestamp ? new Date(bid.timestamp).toLocaleString() : 'Recent'}
                </Text>
              </View>
              <Text style={styles.bidAmount}>
                ${bid.amount.toLocaleString()}
              </Text>
            </View>
          ))
        ) : (
          <Text style={styles.noBids}>No bids yet. Be the first! 🚀</Text>
        )}
      </View>

      <View style={styles.spacer} />
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  centerContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.lg,
  },
  card: {
    backgroundColor: COLORS.surface,
    borderRadius: 12,
    padding: SPACING.md,
    marginVertical: SPACING.xs,
    marginHorizontal: SPACING.md,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  title: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text,
    flex: 1,
    marginRight: SPACING.sm,
  },
  statusBadge: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: 12,
  },
  statusText: {
    ...TYPOGRAPHY.small,
    color: '#fff',
    fontWeight: '600',
  },
  description: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginBottom: SPACING.lg,
    lineHeight: 22,
  },
  priceSection: {
    marginBottom: SPACING.lg,
  },
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  priceLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
  },
  currentPrice: {
    ...TYPOGRAPHY.h3,
    color: COLORS.secondary,
    fontWeight: 'bold',
  },
  startingPrice: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
  },
  bidCount: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '600',
  },
  timeSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.md,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: COLORS.border,
    marginVertical: SPACING.lg,
  },
  timeLabel: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    fontWeight: '600',
  },
  timeRemaining: {
    ...TYPOGRAPHY.h3,
    color: COLORS.error,
    fontWeight: 'bold',
  },
  metaSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  metaText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  bidHint: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
    marginBottom: SPACING.sm,
  },
  bidInput: {
    borderWidth: 1,
    borderColor: COLORS.border,
    borderRadius: 8,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    backgroundColor: '#fff',
    marginBottom: SPACING.md,
  },
  quickBidContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: SPACING.sm,
  },
  quickBidButton: {
    flex: 1,
    marginHorizontal: SPACING.xs,
  },
  bidItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  bidInfo: {
    flex: 1,
  },
  bidder: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text,
  },
  bidTime: {
    ...TYPOGRAPHY.small,
    color: COLORS.textSecondary,
  },
  bidAmount: {
    ...TYPOGRAPHY.body,
    fontWeight: 'bold',
    color: COLORS.secondary,
  },
  noBids: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    textAlign: 'center',
    fontStyle: 'italic',
  },
  loadingText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.primary,
  },
  errorText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.error,
    marginBottom: SPACING.lg,
  },
  spacer: {
    height: SPACING.xl,
  },
});