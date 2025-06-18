import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ApolloProvider } from '@apollo/client';
import { apolloClient } from './src/services/apollo/client';
import { AuthProvider } from './src/services/auth/AuthContext';
import { AppNavigator } from './src/navigation/AppNavigator';

export default function App() {
  return (
    <ApolloProvider client={apolloClient}>
      <SafeAreaProvider>
        <GestureHandlerRootView style={{ flex: 1 }}>
          <AuthProvider>
            <AppNavigator />
            <StatusBar style="light" backgroundColor="#1a73e8" />
          </AuthProvider>
        </GestureHandlerRootView>
      </SafeAreaProvider>
    </ApolloProvider>
  );
}