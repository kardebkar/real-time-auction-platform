import { StyleSheet, View, Text, Alert } from 'react-native';
import { Button } from '@/src/components/common/Button';
import { COLORS, TYPOGRAPHY, SPACING } from '@/src/utils/constants';

export default function HomeScreen() {
  const handleButtonPress = () => {
    Alert.alert('Success!', 'Button component is working!');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>🏆 Auction Platform</Text>
      <Text style={styles.subtitle}>Component testing</Text>
      
      <Button 
        title="Test Button" 
        onPress={handleButtonPress}
        style={styles.button}
      />
      
      <Button 
        title="Secondary Button" 
        onPress={handleButtonPress}
        variant="secondary"
        style={styles.button}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.lg,
  },
  title: {
    ...TYPOGRAPHY.h1,
    color: COLORS.primary,
    marginBottom: SPACING.md,
  },
  subtitle: {
    ...TYPOGRAPHY.body,
    color: COLORS.text,
    marginBottom: SPACING.lg,
  },
  button: {
    marginBottom: SPACING.md,
    width: 200,
  },
});
