import React from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  TouchableOpacity,
  RefreshControl,
  Alert,
} from 'react-native';
import { useQuery } from '@apollo/client';
import { GET_AUCTIONS } from '../../services/apollo/queries';
import { Button } from '../../components/common/Button';
import { Auction } from '../../utils/types';
import { COLORS, SPACING, TYPOGRAPHY } from '../../utils/constants';

interface AuctionListScreenProps {
  navigation: any;
}

export const AuctionListScreen: React.FC<AuctionListScreenProps> = ({ navigation }) => {
  const { data, loading, error, refetch } = useQuery(GET_AUCTIONS, {
    variables: {
      filters: { status: 'ACTIVE' },
      pagination: { limit: 20, offset: 0 }
    },
    pollInterval: 5000, // Real-time updates every 5 seconds
  });

  const handleAuctionPress = (auction: Auction) => {
    navigation.navigate('AuctionDetail', { auctionId: auction.id });
  };

  const renderAuction = ({ item }: { item: Auction }) => (
    <TouchableOpacity 
      style={styles.auctionCard} 
      onPress={() => handleAuctionPress(item)}
    >
      <View style={styles.auctionHeader}>
        <Text style={styles.title} numberOfLines={2}>{item.title}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor(item.status) }]}>
          <Text style={styles.statusText}>{getStatusEmoji(item.status)} {item.status}</Text>
        </View>
      </View>
      
      <Text style={styles.description} numberOfLines={3}>
        {item.description}
      </Text>
      
      <View style={styles.priceContainer}>
        <Text style={styles.currentPrice}>
          💰 ${item.currentPrice.toLocaleString()}
        </Text>
        <Text style={styles.bidCount}>
          📈 {item.bidCount} bids
        </Text>
      </View>
      
      <View style={styles.footer}>
        <Text style={styles.category}>📂 {item.category?.name || 'No Category'}</Text>
        <Text style={styles.seller}>
          👤 {item.seller?.firstName} {item.seller?.lastName}
        </Text>
      </View>
    </TouchableOpacity>
  );

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'ACTIVE': return COLORS.secondary;
      case 'SCHEDULED': return COLORS.warning;
      case 'DRAFT': return COLORS.textSecondary;
      default: return COLORS.error;
    }
  };

  const getStatusEmoji = (status: string) => {
    switch (status) {
      case 'ACTIVE': return '🔥';
      case 'SCHEDULED': return '⏰';
      case 'DRAFT': return '📝';
      default: return '🏁';
    }
  };

  if (loading && !data) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.loadingText}>📱 Loading live auctions...</Text>
        <Text style={styles.subText}>Connecting to API...</Text>
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>❌ Error loading auctions</Text>
        <Text style={styles.errorDetails}>{error.message}</Text>
        <Button 
          title="Retry" 
          onPress={() => refetch()}
          style={styles.retryButton}
        />
      </View>
    );
  }

  // Handle direct array (not wrapped in items)
  const auctions = data?.auctions || [];

  return (
    <View style={styles.container}>
      {auctions.length === 0 ? (
        <View style={styles.centerContainer}>
          <Text style={styles.emptyText}>🏆 No auctions found</Text>
          <Text style={styles.emptySubtext}>Try changing filters or check back later!</Text>
          <Button 
            title="Refresh" 
            onPress={() => refetch()}
            style={styles.refreshButton}
          />
        </View>
      ) : (
        <FlatList
          data={auctions}
          renderItem={renderAuction}
          keyExtractor={(item) => item.id}
          refreshControl={
            <RefreshControl 
              refreshing={loading} 
              onRefresh={refetch}
              tintColor={COLORS.primary}
            />
          }
          showsVerticalScrollIndicator={false}
        />
      )}
    </View>
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
  auctionCard: {
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
  auctionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.sm,
  },
  title: {
    ...TYPOGRAPHY.h3,
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
    marginBottom: SPACING.md,
  },
  priceContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  currentPrice: {
    ...TYPOGRAPHY.h3,
    color: COLORS.secondary,
    fontWeight: 'bold',
  },
  bidCount: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary,
    fontWeight: '600',
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  category: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  seller: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  loadingText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.primary,
    marginBottom: SPACING.sm,
  },
  subText: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
  },
  errorText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.error,
    marginBottom: SPACING.sm,
    textAlign: 'center',
  },
  errorDetails: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  retryButton: {
    width: 120,
  },
  emptyText: {
    ...TYPOGRAPHY.h3,
    color: COLORS.textSecondary,
    marginBottom: SPACING.sm,
  },
  emptySubtext: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    textAlign: 'center',
    marginBottom: SPACING.lg,
  },
  refreshButton: {
    width: 120,
  },
});