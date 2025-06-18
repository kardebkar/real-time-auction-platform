import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
} from 'react-native';
import { useAuth } from '../../services/auth/AuthContext';
import { Button } from '../../components/common/Button';
import { COLORS, SPACING, TYPOGRAPHY } from '../../utils/constants';

export const ProfileScreen = () => {
  const { user, logout } = useAuth();

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', onPress: logout, style: 'destructive' },
      ]
    );
  };

  if (!user) {
    return (
      <View style={styles.container}>
        <Text style={styles.title}>No user data</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* User Info Card */}
      <View style={styles.card}>
        <View style={styles.header}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>
              {user.firstName.charAt(0)}{user.lastName.charAt(0)}
            </Text>
          </View>
          <View style={styles.userInfo}>
            <Text style={styles.name}>
              {user.firstName} {user.lastName}
            </Text>
            <Text style={styles.email}>{user.email}</Text>
            <Text style={styles.role}>Role: {user.role}</Text>
          </View>
        </View>
      </View>

      {/* Account Actions */}
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>⚙️ Account Settings</Text>
        
        <Button
          title="📧 Update Email"
          onPress={() => Alert.alert('Coming Soon', 'Email update feature coming soon!')}
          variant="secondary"
          style={styles.actionButton}
        />
        
        <Button
          title="🔒 Change Password"
          onPress={() => Alert.alert('Coming Soon', 'Password change feature coming soon!')}
          variant="secondary"
          style={styles.actionButton}
        />
      </View>

      {/* App Info */}
      <View style={styles.card}>
        <Text style={styles.sectionTitle}>📱 About This App</Text>
        <Text style={styles.infoText}>✅ Real-time GraphQL integration</Text>
        <Text style={styles.infoText}>✅ Cross-platform bidding</Text>
        <Text style={styles.infoText}>✅ Professional mobile UI</Text>
        <Text style={styles.infoText}>✅ Secure authentication</Text>
        
        <View style={styles.versionInfo}>
          <Text style={styles.versionText}>Version 1.0.0</Text>
          <Text style={styles.versionText}>Built with Expo & React Native</Text>
        </View>
      </View>

      {/* Logout */}
      <View style={styles.card}>
        <Button
          title="🚪 Logout"
          onPress={handleLogout}
          variant="danger"
        />
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
  card: {
    backgroundColor: COLORS.surface,
    borderRadius: 12,
    padding: SPACING.md,
    marginVertical: SPACING.xs,
    marginHorizontal: SPACING.md,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  avatarText: {
    ...TYPOGRAPHY.h3,
    color: '#fff',
    fontWeight: 'bold',
  },
  userInfo: {
    flex: 1,
  },
  name: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text,
    marginBottom: SPACING.xs,
  },
  email: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginBottom: SPACING.xs,
  },
  role: {
    ...TYPOGRAPHY.caption,
    color: COLORS.primary,
    fontWeight: '600',
  },
  sectionTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text,
    marginBottom: SPACING.md,
  },
  actionButton: {
    marginBottom: SPACING.sm,
  },
  infoText: {
    ...TYPOGRAPHY.body,
    color: COLORS.textSecondary,
    marginBottom: SPACING.xs,
  },
  versionInfo: {
    marginTop: SPACING.md,
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border,
    alignItems: 'center',
  },
  versionText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.textSecondary,
  },
  spacer: {
    height: SPACING.xl,
  },
  title: {
    ...TYPOGRAPHY.h2,
    color: COLORS.text,
    textAlign: 'center',
    marginTop: SPACING.xl,
  },
});