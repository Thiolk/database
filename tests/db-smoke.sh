#!/usr/bin/env bash
set -euo pipefail

# Paths (run from repo root)
COMPOSE_FILE="deploy/docker/docker-compose.yml"
ENV_FILE="deploy/docker/.env"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERROR: Missing $COMPOSE_FILE"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: Missing $ENV_FILE (copy from deploy/docker/.env.example)"
  exit 1
fi

echo "Reset DB (fresh init.sql run)"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v || true

echo "Start DB"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

# Pull creds from .env (simple parser for KEY=VALUE lines)
get_env() {
  local key="$1"
  # strip comments, handle KEY=VALUE, remove possible quotes
  awk -F= -v k="$key" '
    $0 !~ /^[[:space:]]*#/ && $1 == k {
      val = substr($0, index($0,$2))
      gsub(/^"/, "", val); gsub(/"$/, "", val)
      gsub(/^'\''/, "", val); gsub(/'\''$/, "", val)
      print val
    }' "$ENV_FILE" | tail -n 1
}

POSTGRES_DB="$(get_env POSTGRES_DB)"
POSTGRES_USER="$(get_env POSTGRES_USER)"
POSTGRES_PASSWORD="$(get_env POSTGRES_PASSWORD)"

if [[ -z "${POSTGRES_DB}" || -z "${POSTGRES_USER}" || -z "${POSTGRES_PASSWORD}" ]]; then
  echo "ERROR: POSTGRES_DB/POSTGRES_USER/POSTGRES_PASSWORD must exist in $ENV_FILE"
  exit 1
fi

# Figure out container id for the DB service (assumes only one service is running)
DB_CID="$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q | head -n 1)"
if [[ -z "$DB_CID" ]]; then
  echo "ERROR: Could not find running DB container from compose."
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
  exit 1
fi

echo "Wait for Postgres readiness"
for i in {1..60}; do
  if docker exec "$DB_CID" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    echo "Postgres is ready."
    break
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "ERROR: Postgres not ready after 60s"
    docker logs "$DB_CID" --tail 200 || true
    exit 1
  fi
  sleep 1
done

psql_in() {
  local sql="$1"
  docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CID" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -qtAX -c "$sql"
}

assert_eq() {
  local got="$1"
  local expected="$2"
  local msg="${3:-assert_eq failed (no message provided)}"
  if [[ "$got" != "$expected" ]]; then
    echo "ASSERT FAIL: $msg"
    echo "  expected: $expected"
    echo "  got:      $got"
    exit 1
  fi
}

assert_not_empty() {
  local got="$1"
  local msg="${2:-assert_not_empty failed (no message provided)}"
  if [[ -z "$got" || "$got" == "NULL" ]]; then
    echo "ASSERT FAIL: $msg"
    echo "  got: $got"
    exit 1
  fi
}

echo "Contract tests: tables exist"
t1="$(psql_in "SELECT to_regclass('public.products');")"
t2="$(psql_in "SELECT to_regclass('public.orders');")"
assert_eq "$t1" "products" "products table should exist"
assert_eq "$t2" "orders" "orders table should exist"

echo "Contract tests: required columns exist"
# products: id, name, price, description, created_at
c_products="$(psql_in "
  SELECT string_agg(column_name, ',' ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='products';
")"
# orders: id, product_id, quantity, total_price, status, created_at
c_orders="$(psql_in "
  SELECT string_agg(column_name, ',' ORDER BY ordinal_position)
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='orders';
")"

# Simple presence checks (avoid strict ordering to be tolerant)
for col in id name price description created_at; do
  [[ "$c_products" == *"$col"* ]] || { echo "ASSERT FAIL: products missing column '$col' (got: $c_products)"; exit 1; }
done
for col in id product_id quantity total_price status created_at; do
  [[ "$c_orders" == *"$col"* ]] || { echo "ASSERT FAIL: orders missing column '$col' (got: $c_orders)"; exit 1; }
done

echo "Contract tests: FK exists orders.product_id -> products.id"
fk_count="$(psql_in "
  SELECT COUNT(*)
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.table_schema = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
   AND ccu.table_schema = tc.table_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name = 'orders'
    AND kcu.column_name = 'product_id'
    AND ccu.table_name = 'products'
    AND ccu.column_name = 'id';
")"
assert_eq "$fk_count" "1" "orders.product_id should reference products.id"

echo "Seed data test: 5 products inserted"
seed_count="$(psql_in "SELECT COUNT(*) FROM products;")"
assert_eq "$seed_count" "5" "products should have 5 seed rows"

echo "Integration test: insert product, then insert valid order"
new_pid="$(psql_in "INSERT INTO products (name, price, description) VALUES ('TestProduct', 12.34, 'From CI') RETURNING id;")"
assert_not_empty "$new_pid" "insert product should return id"

order_id="$(psql_in "
  INSERT INTO orders (product_id, quantity, total_price, status)
  VALUES ($new_pid, 2, 24.68, 'pending')
  RETURNING id;
")"
assert_not_empty "$order_id" "insert order should return id"

echo "Integration test: FK should reject invalid product_id"
set +e
psql_in "INSERT INTO orders (product_id, quantity, total_price) VALUES (999999, 1, 9.99);" >/dev/null 2>&1
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "ASSERT FAIL: expected FK violation inserting order with non-existent product_id"
  exit 1
fi

echo "All DB tests passed ✅"

echo "Cleanup"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down -v