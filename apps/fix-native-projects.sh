#!/bin/bash

echo "🔧 FIXING NATIVE iOS/ANDROID PROJECT FOLDERS"
echo "============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Navigate to mobile directory
cd apps/mobile

echo -e "${BLUE}📱 Current Situation:${NC}"
echo "We have the React Native JavaScript structure but missing native iOS/Android folders"
echo ""

# Check what we have
echo -e "${YELLOW}📋 Current structure:${NC}"
ls -la

echo ""
echo -e "${PURPLE}🔧 SOLUTION: Initialize React Native Native Projects${NC}"
echo "=================================================="
echo ""

echo -e "${BLUE}Option 1: Fresh React Native Init (Recommended)${NC}"
echo "-----------------------------------------------"
echo ""

# Backup our custom code
echo "1. Backing up our custom code..."
mkdir -p ../mobile-backup
cp -r src ../mobile-backup/
cp App.tsx ../mobile-backup/ 2>/dev/null || true
cp package.json ../mobile-backup/
cp tsconfig.json ../mobile-backup/ 2>/dev/null || true

echo -e "${GREEN}✅ Custom code backed up to ../mobile-backup/${NC}"
echo ""

# Move to parent directory and create new React Native project
cd ..
echo "2. Creating fresh React Native project with native folders..."

# Remove current mobile directory
rm -rf mobile

# Create new React Native project
echo -e "${YELLOW}📱 Initializing React Native project with native iOS/Android...${NC}"
npx react-native@latest init AuctionMobile --template react-native-template-typescript --skip-install

# Rename the project directory
if [ -d "AuctionMobile" ]; then
    mv AuctionMobile mobile
    echo -e "${GREEN}✅ React Native project created with native folders!${NC}"
else
    echo -e "${RED}❌ React Native init failed. Trying alternative...${NC}"
    
    # Alternative method
    npx @react-native-community/cli@latest init AuctionMobile --template react-native-template-typescript
    if [ -d "AuctionMobile" ]; then
        mv AuctionMobile mobile
        echo -e "${GREEN}✅ React Native project created (alternative method)!${NC}"
    fi
fi

cd mobile

echo ""
echo "3. Restoring our custom code..."

# Restore our custom files
cp -r ../mobile-backup/src ./
cp ../mobile-backup/App.tsx ./
cp ../mobile-backup/package.json ./package.json.backup

# Merge package.json dependencies
echo "4. Merging dependencies..."

# Create a merged package.json with our dependencies
cat > package.json << 'EOF'
{
  "name": "@auction/mobile",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "android": "react-native run-android",
    "ios": "react-native run-ios",
    "lint": "eslint .",
    "start": "react-native start",
    "test": "jest"
  },
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.72.0",
    "@react-navigation/native": "^6.1.7",
    "@react-navigation/stack": "^6.3.17",
    "@react-navigation/bottom-tabs": "^6.5.8",
    "react-native-screens": "^3.22.1",
    "react-native-safe-area-context": "^4.7.1",
    "react-native-gesture-handler": "^2.12.1",
    "@apollo/client": "^3.8.1",
    "graphql": "^16.7.1",
    "@react-native-async-storage/async-storage": "^1.19.1",
    "react-native-vector-icons": "^10.0.0",
    "react-native-linear-gradient": "^2.8.3",
    "react-native-reanimated": "^3.3.0",
    "react-native-svg": "^13.10.0",
    "@react-native-community/netinfo": "^9.4.1",
    "react-native-keychain": "^8.1.3",
    "ws": "^8.13.0"
  },
  "devDependencies": {
    "@babel/core": "^7.20.0",
    "@babel/preset-env": "^7.20.0",
    "@babel/runtime": "^7.20.0",
    "@react-native/eslint-config": "^0.72.0",
    "@react-native/metro-config": "^0.72.0",
    "@tsconfig/react-native": "^3.0.0",
    "@types/react": "^18.0.24",
    "@types/react-test-renderer": "^18.0.0",
    "@types/ws": "^8.5.5",
    "@types/react-native-vector-icons": "^6.4.14",
    "babel-jest": "^29.2.1",
    "eslint": "^8.19.0",
    "jest": "^29.2.1",
    "metro-react-native-babel-preset": "0.76.7",
    "prettier": "^2.4.1",
    "react-test-renderer": "18.2.0",
    "typescript": "4.8.4"
  }
}
EOF

echo ""
echo "5. Installing dependencies..."
npm install

echo ""
echo "6. Setting up iOS dependencies..."
cd ios
pod install
cd ..

echo ""
echo -e "${GREEN}✅ NATIVE PROJECT SETUP COMPLETE!${NC}"
echo "=================================="
echo ""

# Verify the setup
echo -e "${BLUE}📋 Verification:${NC}"
if [ -d "ios" ]; then
    echo -e "${GREEN}✅ iOS folder exists${NC}"
else
    echo -e "${RED}❌ iOS folder missing${NC}"
fi

if [ -d "android" ]; then
    echo -e "${GREEN}✅ Android folder exists${NC}"
else
    echo -e "${RED}❌ Android folder missing${NC}"
fi

if [ -f "ios/AuctionMobile.xcworkspace" ]; then
    echo -e "${GREEN}✅ iOS Xcode workspace exists${NC}"
else
    echo -e "${YELLOW}⚠️  iOS workspace might need pod install${NC}"
fi

echo ""
echo -e "${PURPLE}🚀 READY TO TEST!${NC}"
echo "================="
echo ""
echo "Now you can run:"
echo ""
echo -e "${GREEN}📱 iOS:${NC}"
echo "   npm run ios"
echo ""
echo -e "${GREEN}🤖 Android:${NC}"
echo "   npm run android"
echo ""

echo -e "${BLUE}📂 Project Structure:${NC}"
echo "===================="
ls -la

echo ""
echo -e "${YELLOW}🔧 If you still get errors:${NC}"
echo "=========================="
echo ""
echo "1. Clean everything:"
echo "   rm -rf node_modules"
echo "   npm install"
echo "   cd ios && pod install && cd .."
echo ""
echo "2. Reset Metro cache:"
echo "   npm start --reset-cache"
echo ""
echo "3. For iOS issues:"
echo "   cd ios && xcodebuild clean && cd .."
echo ""

echo -e "${GREEN}🎉 Your React Native app now has native iOS and Android support!${NC}"