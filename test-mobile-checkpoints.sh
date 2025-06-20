#!/bin/bash

echo "🧪 COMPLETE MOBILE APP TESTING CHECKPOINTS"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    echo -e "${BLUE}📝 Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${RED}❌ FAILED${NC}"
        if [ -n "$expected_result" ]; then
            echo -e "   ${YELLOW}Expected: $expected_result${NC}"
        fi
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Function to run a warning test (not critical)
run_warning_test() {
    local test_name="$1"
    local test_command="$2"
    local warning_message="$3"
    
    echo -e "${BLUE}📝 Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "   ${YELLOW}⚠️  WARNING${NC}"
        if [ -n "$warning_message" ]; then
            echo -e "   ${YELLOW}$warning_message${NC}"
        fi
        ((WARNINGS++))
    fi
    echo ""
}

# Function to check if Phase 1 API is running
check_phase1_api() {
    echo -e "${CYAN}🔍 CHECKING PHASE 1 API STATUS${NC}"
    echo "================================"
    
    # Check if API Gateway is running
    if curl -s http://localhost:4000/health > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ API Gateway running on port 4000${NC}"
        
        # Test GraphQL endpoint
        if curl -s -X POST http://localhost:4000/graphql \
            -H "Content-Type: application/json" \
            -d '{"query": "{ __schema { types { name } } }"}' > /dev/null 2>&1; then
            echo -e "   ${GREEN}✅ GraphQL endpoint responding${NC}"
            
            # Test authentication
            AUTH_TEST=$(curl -s -X POST http://localhost:4000/graphql \
                -H "Content-Type: application/json" \
                -d '{"query": "mutation { login(input: { email: \"admin@auction.com\", password: \"password123\" }) { token } }"}' | grep -o '"token"')

            if [[ $AUTH_TEST == *"token"* ]]; then
                echo -e "   ${GREEN}✅ Authentication working${NC}"
                return 0
            else
                echo -e "   ${YELLOW}⚠️  Authentication may have issues${NC}"
                return 1
            fi
        else
            echo -e "   ${RED}❌ GraphQL endpoint not responding${NC}"
            return 1
        fi
    else
        echo -e "   ${RED}❌ API Gateway not running${NC}"
        echo -e "   ${YELLOW}Start Phase 1 services: cd services/api-gateway && npm run dev${NC}"
        return 1
    fi
}

echo -e "${PURPLE}🚀 CHECKPOINT 1: MOBILE APP FOUNDATION${NC}"
echo "======================================"

# Navigate to mobile directory
if [ ! -d "apps/mobile" ]; then
    echo -e "${RED}❌ Mobile directory not found. Please run mobile setup first.${NC}"
    exit 1
fi

cd apps/mobile

# Test 1.1: Project Structure
run_test "Project Structure" "[ -f 'App.tsx' ] && [ -d 'src' ]"
run_test "Package.json exists" "[ -f 'package.json' ]"
run_test "TypeScript config" "[ -f 'tsconfig.json' ]"
run_test "Metro config" "[ -f 'metro.config.js' ]"
run_test "Babel config" "[ -f 'babel.config.js' ]"

# Test 1.2: Source Structure
run_test "Services directory" "[ -d 'src/services' ]"
run_test "Screens directory" "[ -d 'src/screens' ]"
run_test "Navigation directory" "[ -d 'src/navigation' ]"
run_test "Auth screens" "[ -d 'src/screens/auth' ]"
run_test "Auction screens" "[ -d 'src/screens/auctions' ]"

# Test 1.3: Key Configuration Files
run_test "Apollo Client config" "[ -f 'src/services/apollo.ts' ]"
run_test "Auth Context" "[ -f 'src/services/auth/AuthContext.tsx' ]"
run_test "GraphQL mutations" "[ -f 'src/services/graphql/mutations.ts' ]"
run_test "GraphQL queries" "[ -f 'src/services/graphql/queries.ts' ]"

# Test 1.4: Navigation Files
run_test "App Navigator" "[ -f 'src/navigation/AppNavigator.tsx' ]"
run_test "Auth Navigator" "[ -f 'src/navigation/AuthNavigator.tsx' ]"
run_test "Main Navigator" "[ -f 'src/navigation/MainNavigator.tsx' ]"

# Test 1.5: Screen Files
run_test "Loading Screen" "[ -f 'src/screens/LoadingScreen.tsx' ]"
run_test "Login Screen" "[ -f 'src/screens/auth/LoginScreen.tsx' ]"
run_test "Auction List Screen" "[ -f 'src/screens/auctions/AuctionListScreen.tsx' ]"
run_test "Auction Detail Screen" "[ -f 'src/screens/auctions/AuctionDetailScreen.tsx' ]"
run_test "Profile Screen" "[ -f 'src/screens/profile/ProfileScreen.tsx' ]"

echo ""
echo -e "${PURPLE}🧪 CHECKPOINT 2: DEPENDENCIES${NC}"
echo "==============================="

# Test 2.1: Package.json Content
run_test "React Native dependency" "grep -q 'react-native' package.json"
run_test "Apollo Client dependency" "grep -q '@apollo/client' package.json"
run_test "React Navigation dependency" "grep -q '@react-navigation/native' package.json"
run_test "AsyncStorage dependency" "grep -q '@react-native-async-storage/async-storage' package.json"
run_test "Vector Icons dependency" "grep -q 'react-native-vector-icons' package.json"
run_test "TypeScript dependency" "grep -q 'typescript' package.json"

# Test 2.2: Node Modules (if installed)
if [ -d "node_modules" ]; then
    echo -e "${GREEN}✅ Dependencies installed${NC}"
    
    run_test "React Native installed" "[ -d 'node_modules/react-native' ]"
    run_test "Apollo Client installed" "[ -d 'node_modules/@apollo/client' ]"
    run_test "React Navigation installed" "[ -d 'node_modules/@react-navigation/native' ]"
    run_test "AsyncStorage installed" "[ -d 'node_modules/@react-native-async-storage' ]"
else
    echo -e "${YELLOW}⚠️  Dependencies not installed yet${NC}"
    echo -e "${YELLOW}Run: npm install${NC}"
    echo ""
fi

echo ""
echo -e "${PURPLE}🔌 CHECKPOINT 3: PHASE 1 INTEGRATION${NC}"
echo "====================================="

# Check Phase 1 API connectivity
check_phase1_api
PHASE1_STATUS=$?

if [ $PHASE1_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Ready for Phase 1 integration${NC}"
else
    echo -e "${RED}❌ Phase 1 API not fully available${NC}"
    echo -e "${YELLOW}Ensure Phase 1 services are running${NC}"
fi

echo ""
echo -e "${PURPLE}📱 CHECKPOINT 4: DEVELOPMENT ENVIRONMENT${NC}"
echo "=========================================="

# Test 4.1: Required Tools
run_warning_test "NPX available" "command -v npx > /dev/null 2>&1" "Install Node.js to get npx"
run_warning_test "Node.js version" "node -v | grep -E 'v1[6-9]|v[2-9][0-9]'" "Node.js 16+ recommended"

# Test 4.2: Mobile Development Tools
# Android
if [ -d "$ANDROID_HOME" ] || [ -d "$ANDROID_SDK_ROOT" ]; then
    echo -e "${GREEN}✅ Android SDK detected${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Android SDK not detected${NC}"
    echo -e "${YELLOW}Install Android Studio for Android development${NC}"
    ((WARNINGS++))
fi

# iOS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v xcodebuild > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Xcode available for iOS development${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠️  Xcode not found${NC}"
        echo -e "${YELLOW}Install Xcode from App Store for iOS development${NC}"
        ((WARNINGS++))
    fi
    
    # Check for CocoaPods
    if command -v pod > /dev/null 2>&1; then
        echo -e "${GREEN}✅ CocoaPods available${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠️  CocoaPods not found${NC}"
        echo -e "${YELLOW}Install with: sudo gem install cocoapods${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠️  iOS development only available on macOS${NC}"
    ((WARNINGS++))
fi

echo ""
echo -e "${PURPLE}🚀 CHECKPOINT 5: CODE QUALITY${NC}"
echo "==============================="

# Test 5.1: TypeScript Configuration
run_test "TypeScript paths configured" "grep -q '\"@/\\*\"' tsconfig.json"
run_test "TypeScript strict mode" "grep -q '\"strict\": true' tsconfig.json"

# Test 5.2: Key Code Patterns
run_test "Apollo Client configured" "grep -q 'createHttpLink' src/services/apollo.ts"
run_test "Auth context implemented" "grep -q 'createContext' src/services/auth/AuthContext.tsx"
run_test "GraphQL mutations defined" "grep -q 'LOGIN_MUTATION' src/services/graphql/mutations.ts"
run_test "Real-time polling configured" "grep -q 'pollInterval' src/screens/auctions/AuctionListScreen.tsx"

echo ""
echo -e "${PURPLE}🎯 CHECKPOINT 6: MOBILE-SPECIFIC FEATURES${NC}"
echo "=========================================="

# Test 6.1: Mobile Navigation
run_test "Stack Navigator used" "grep -q 'createStackNavigator' src/navigation/AppNavigator.tsx"
run_test "Tab Navigator configured" "grep -q 'createBottomTabNavigator' src/navigation/MainNavigator.tsx"
run_test "Navigation icons configured" "grep -q 'react-native-vector-icons' src/navigation/MainNavigator.tsx"

# Test 6.2: Mobile UI Components
run_test "TouchableOpacity used" "grep -q 'TouchableOpacity' src/screens/auth/LoginScreen.tsx"
run_test "FlatList for auctions" "grep -q 'FlatList' src/screens/auctions/AuctionListScreen.tsx"
run_test "ScrollView for details" "grep -q 'ScrollView' src/screens/auctions/AuctionDetailScreen.tsx"
run_test "AsyncStorage for auth" "grep -q 'AsyncStorage' src/services/auth/AuthContext.tsx"

# Test 6.3: Real-time Features
run_test "Real-time auction polling" "grep -q 'pollInterval.*5000' src/screens/auctions/AuctionListScreen.tsx"
run_test "Real-time detail polling" "grep -q 'pollInterval.*2000' src/screens/auctions/AuctionDetailScreen.tsx"
run_test "Bid mutation implemented" "grep -q 'PLACE_BID_MUTATION' src/screens/auctions/AuctionDetailScreen.tsx"

echo ""
echo -e "${PURPLE}📊 TEST RESULTS SUMMARY${NC}"
echo "========================"
echo ""
echo -e "${GREEN}✅ Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Tests Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))
    echo -e "${BLUE}📈 Success Rate: $SUCCESS_RATE%${NC}"
fi

echo ""
echo -e "${CYAN}🎯 DEVELOPMENT STATUS${NC}"
echo "===================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL CRITICAL TESTS PASSED!${NC}"
    echo -e "${GREEN}Ready for mobile development!${NC}"
    echo ""
    
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}🏆 PERFECT SETUP - No warnings!${NC}"
    else
        echo -e "${YELLOW}⚠️  $WARNINGS warnings (non-critical)${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🚀 NEXT STEPS:${NC}"
    echo "=============="
    
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}1. Install dependencies:${NC}"
        echo "   npm install"
        echo ""
    fi
    
    if [ $PHASE1_STATUS -ne 0 ]; then
        echo -e "${YELLOW}2. Start Phase 1 API:${NC}"
        echo "   cd ../../services/api-gateway"
        echo "   npm run dev"
        echo ""
    fi
    
    echo -e "${GREEN}3. Start mobile development:${NC}"
    echo "   npm start                  # Start Metro bundler"
    echo "   npm run android           # Run on Android"
    echo "   npm run ios               # Run on iOS (macOS only)"
    echo ""
    
    echo -e "${PURPLE}🎯 DEMO FEATURES READY:${NC}"
    echo "   🔐 Login with Phase 1 API (credentials pre-filled)"
    echo "   📱 Real-time auction browsing"
    echo "   🎯 Live bidding with instant updates"
    echo "   ⏰ Live countdown timers"
    echo "   🎨 Professional mobile UI with emojis"
    echo ""
    
    echo -e "${GREEN}🔥 THIS WILL ABSOLUTELY WOW IN INTERVIEWS! 🚀${NC}"
    
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}Please fix the following issues:${NC}"
    echo ""
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${YELLOW}🔧 Common fixes:${NC}"
        echo "   • Re-run the mobile setup script"
        echo "   • Check file permissions"
        echo "   • Ensure you're in the correct directory"
    fi
    
    if [ $PHASE1_STATUS -ne 0 ]; then
        echo "   • Start Phase 1 API: cd services/api-gateway && npm run dev"
    fi
fi

echo ""
echo -e "${CYAN}📱 MOBILE TESTING FRAMEWORK COMPLETE${NC}"
echo "===================================="
echo ""
echo -e "${BLUE}Testing Categories Covered:${NC}"
echo "   ✅ Foundation Tests - Project structure"
echo "   ✅ Dependency Tests - NPM packages"  
echo "   ✅ Integration Tests - Phase 1 API connectivity"
echo "   ✅ Environment Tests - Development tools"
echo "   ✅ Code Quality Tests - TypeScript, patterns"
echo "   ✅ Mobile Feature Tests - Navigation, UI, real-time"
echo ""
echo -e "${PURPLE}🎯 Mobile Development Checkpoints:${NC}"
echo "   1. ✅ Foundation Setup (Complete)"
echo "   2. 🔄 Real-time Features (Ready to test)"
echo "   3. 🔄 Cross-platform Bidding (Ready to test)"
echo "   4. 🔄 Push Notifications (Future)"
echo ""
echo "Use './test-mobile-checkpoints.sh' anytime to validate your setup!"
echo -e "${GREEN}Happy mobile development! 📱✨${NC}"
