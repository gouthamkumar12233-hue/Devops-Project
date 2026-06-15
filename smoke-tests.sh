#!/bin/bash

# Smoke tests for validating deployment
# Usage: ./smoke-tests.sh <API_ENDPOINT>

set -e

API_ENDPOINT=${1:-"http://localhost:3000"}
TIMEOUT=30
MAX_RETRIES=5
RETRY_DELAY=5

echo "Running smoke tests against: $API_ENDPOINT"
echo "========================================"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local endpoint=$1
    local expected_status=$2
    local test_name=$3
    local retry_count=0
    
    echo -e "${YELLOW}Testing:${NC} $test_name"
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        status_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 5 \
            --max-time $TIMEOUT \
            "$API_ENDPOINT$endpoint")
        
        if [ "$status_code" = "$expected_status" ]; then
            echo -e "${GREEN}✓ PASS${NC}: $test_name (HTTP $status_code)"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}⟳ Retry${NC} $retry_count/$MAX_RETRIES - Status: $status_code (expected $expected_status)"
            sleep $RETRY_DELAY
        fi
    done
    
    echo -e "${RED}✗ FAIL${NC}: $test_name (HTTP $status_code, expected $expected_status)"
    return 1
}

# Function to test response content
test_response_content() {
    local endpoint=$1
    local expected_content=$2
    local test_name=$3
    
    echo -e "${YELLOW}Testing:${NC} $test_name"
    
    response=$(curl -s "$API_ENDPOINT$endpoint")
    
    if echo "$response" | grep -q "$expected_content"; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "Response: $response"
        return 1
    fi
}

# Test counters
tests_passed=0
tests_failed=0

# Run tests
echo ""
echo "=== Health Checks ==="
if test_endpoint "/health" "200" "Health endpoint"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

echo ""
echo "=== Readiness Checks ==="
if test_endpoint "/ready" "200" "Ready endpoint"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

echo ""
echo "=== API Checks ==="
if test_endpoint "/api/v1/status" "200" "API status endpoint"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

if test_response_content "/api/v1/status" "version" "API version in response"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

echo ""
echo "=== 404 Handling ==="
if test_endpoint "/nonexistent" "404" "404 for non-existent endpoint"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

# Summary
echo ""
echo "========================================"
echo -e "Tests Passed: ${GREEN}$tests_passed${NC}"
echo -e "Tests Failed: ${RED}$tests_failed${NC}"
echo "========================================"

if [ $tests_failed -eq 0 ]; then
    echo -e "${GREEN}All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
