#!/usr/bin/env bash
#
# Sends many booking requests for the same listing and nights at the same moment,
# then counts the responses. Exactly one should succeed (200) and the rest should be
# rejected as conflicts (409): the booking flow locks the listing row, and a database
# constraint forbids overlapping stays.
#
# Usage:
#   export JSESSIONID=...  XSRF_TOKEN=...   # from a guest's logged-in browser session
#   scripts/concurrent-bookings.sh <listing-id> <check-in> <check-out> [requests]
#
# Example:
#   scripts/concurrent-bookings.sh 3f2a...e9 2027-03-10 2027-03-12
#
# Copy JSESSIONID and XSRF-TOKEN from the browser's cookies for the app
# (Safari: Web Inspector > Storage > Cookies). Log in as a guest, not the
# listing's host: hosts can't book their own listings.

set -euo pipefail

LISTING="${1:?listing id required}"
CHECK_IN="${2:?check-in date (YYYY-MM-DD) required}"
CHECK_OUT="${3:?check-out date (YYYY-MM-DD) required}"
REQUESTS="${4:-20}"
BASE_URL="${BASE_URL:-http://localhost:4200}"

: "${JSESSIONID:?export JSESSIONID from your browser session}"
: "${XSRF_TOKEN:?export XSRF_TOKEN from your browser session}"

BODY="{\"listingPublicId\":\"$LISTING\",\"startDate\":\"$CHECK_IN\",\"endDate\":\"$CHECK_OUT\"}"

echo "Sending $REQUESTS booking requests at once for $CHECK_IN to $CHECK_OUT..."
echo

# xargs -P starts all the requests in parallel; each prints its HTTP status code.
seq "$REQUESTS" | xargs -P "$REQUESTS" -I{} \
  curl -s -o /dev/null -w '%{http_code}\n' \
    -X POST "$BASE_URL/api/booking/create" \
    -H 'Content-Type: application/json' \
    -H "X-XSRF-TOKEN: $XSRF_TOKEN" \
    -b "JSESSIONID=$JSESSIONID; XSRF-TOKEN=$XSRF_TOKEN" \
    -d "$BODY" \
  | sort | uniq -c \
  | awk '{
      label = ($2 == "200") ? "booked" : ($2 == "409") ? "rejected: dates already taken" : "unexpected"
      printf "  %3d x %s  %s\n", $1, $2, label
    }'
