#!/bin/bash

# Kill any running instance on port 5000
lsof -ti:5000 | xargs kill -9 2>/dev/null || true

# Start the server in background
echo "Starting server..."
cd /Users/wen/Desktop/Personal/Projects/Follow/follow-server/src/Follow.Api
dotnet run > server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for server to start..."
# Loop to check if port 5000 is open
for i in {1..30}; do
    if lsof -Pi :5000 -sTCP:LISTEN -t >/dev/null ; then
        echo "Server is up!"
        break
    fi
    sleep 1
done

# Request a protected endpoint without token
echo "Sending request to protected endpoint..."
RESPONSE=$(curl -s -v http://localhost:5000/api/user/favorites 2>&1)

echo "Response Output:"
echo "$RESPONSE"

# Check for JSON structure
if echo "$RESPONSE" | grep -q '"code":401'; then
    echo "SUCCESS: Found code 401 in response"
else
    echo "FAILURE: Did not find code 401 in response"
    grep "code" <<< "$RESPONSE"
fi

if echo "$RESPONSE" | grep -q '"message":"Unauthorized"'; then
    echo "SUCCESS: Found message Unauthorized in response"
else
    echo "FAILURE: Did not find message Unauthorized in response"
fi

# Cleanup
echo "Stopping server..."
kill $SERVER_PID
