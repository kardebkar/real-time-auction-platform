import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { AuctionListScreen } from '../screens/auction/AuctionListScreen';
import { ProfileScreen } from '../screens/profile/ProfileScreen';
import { COLORS } from '../utils/constants';

const Tab = createBottomTabNavigator();

export const TabNavigator = () => {
  return (
    <Tab.Navigator
      screenOptions={{
        tabBarActiveTintColor: COLORS.primary,
        tabBarInactiveTintColor: COLORS.textSecondary,
        headerStyle: {
          backgroundColor: COLORS.primary,
        },
        headerTintColor: '#fff',
        headerTitleStyle: {
          fontWeight: 'bold',
        },
      }}
    >
      <Tab.Screen 
        name="Auctions" 
        component={AuctionListScreen}
        options={{
          tabBarLabel: 'Auctions',
          title: '🏆 Live Auctions',
        }}
      />
      <Tab.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{
          tabBarLabel: 'Profile',
          title: '👤 Profile',
        }}
      />
    </Tab.Navigator>
  );
};