"""
BiteStream PostgreSQL Seeder

Generates:
    - 10,000+ users
    - 500+ restaurants
    - 100,000+ orders
    - wallet audit records automatically through the trigger

Environment variables:

PGHOST
PGPORT
PGDATABASE
PGUSER
PGPASSWORD

Example:

python3 postgres_seeder.py --users 10000 --restaurants 500 --orders 120000
"""

import argparse
import os
import random
import uuid

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import psycopg2
from psycopg2.extras import execute_values


def get_connection():

    return psycopg2.connect(

        host=os.getenv(
            "PGHOST",
            "localhost"
        ),

        port=int(
            os.getenv(
                "PGPORT",
                "5432"
            )
        ),

        dbname=os.getenv(
            "PGDATABASE",
            "bitestream"
        ),

        user=os.getenv(
            "PGUSER",
            "postgres"
        ),

        password=os.getenv(
            "PGPASSWORD",
            ""
        )
    )


def chunks(data, size):

    for i in range(
        0,
        len(data),
        size
    ):

        yield data[
            i:i + size
        ]


def seed_database(
    users_count,
    restaurants_count,
    orders_count,
    batch_size,
    random_seed
):

    random.seed(random_seed)

    connection = get_connection()

    connection.autocommit = False

    try:

        cursor = connection.cursor()


        # =================================================
        # USERS
        # =================================================

        print("Generating users...")

        users = []

        balances = {}

        for _ in range(users_count):

            user_id = str(
                uuid.uuid4()
            )

            balance = Decimal(
                random.randint(
                    5000,
                    100000
                )
            )

            users.append(
                (
                    user_id,
                    f"User-{user_id[:8]}",
                    balance
                )
            )

            balances[user_id] = balance


        for batch in chunks(
            users,
            batch_size
        ):

            execute_values(

                cursor,

                """
                INSERT INTO users
                    (id, name, wallet_balance)
                VALUES %s
                """,

                batch
            )


        print(
            f"Users inserted: {len(users):,}"
        )


        # =================================================
        # RESTAURANTS
        # =================================================

        print(
            "Generating restaurants..."
        )

        restaurants = []

        for i in range(
            restaurants_count
        ):

            latitude = random.uniform(
                12.80,
                13.10
            )

            longitude = random.uniform(
                77.45,
                77.75
            )

            restaurants.append(

                (
                    str(uuid.uuid4()),

                    f"Restaurant-{i + 1}",

                    latitude,

                    longitude
                )
            )


        for batch in chunks(
            restaurants,
            batch_size
        ):

            execute_values(

                cursor,

                """
                INSERT INTO restaurants
                    (id, name, latitude, longitude)
                VALUES %s
                """,

                batch
            )


        restaurant_ids = [
            restaurant[0]
            for restaurant in restaurants
        ]

        user_ids = list(
            balances.keys()
        )


        print(
            f"Restaurants inserted: "
            f"{len(restaurants):,}"
        )


        # =================================================
        # ORDERS
        # =================================================

        print(
            f"Generating {orders_count:,} orders..."
        )

        inserted_orders = 0

        active_status_users = set()

        while inserted_orders < orders_count:

            current_batch = min(
                batch_size,
                orders_count - inserted_orders
            )

            orders = []

            wallet_updates = []


            for _ in range(
                current_batch
            ):

                # Find a user with enough money.

                for _attempt in range(20):

                    user_id = random.choice(
                        user_ids
                    )

                    amount = Decimal(
                        random.randint(
                            100,
                            2500
                        )
                    )

                    if (
                        balances[user_id]
                        >= amount
                    ):
                        break

                else:

                    # Add credit if necessary.

                    user_id = random.choice(
                        user_ids
                    )

                    credit = Decimal(
                        "10000"
                    )

                    balances[user_id] += credit

                    cursor.execute(

                        """
                        UPDATE users
                        SET wallet_balance =
                            wallet_balance + %s
                        WHERE id = %s
                        """,

                        (
                            credit,
                            user_id
                        )
                    )

                    amount = Decimal(
                        random.randint(
                            100,
                            2500
                        )
                    )
                if user_id in active_status_users:
                    status = "DELIVERED"
                else:
                    status = random.choices(
                        ["DELIVERED", "PREPARING", "DELIVERING"],
                        weights=[80, 10, 10],
                        k=1
                    )[0]

                    if status != "DELIVERED":
                        active_status_users.add(user_id)

                balances[user_id] -= amount


                wallet_updates.append(
                    (
                        amount,
                        user_id
                    )
                )


                order_id = str(
                    uuid.uuid4()
                )

                restaurant_id = random.choice(
                    restaurant_ids
                )


                created_at = (

                    datetime.now(
                        timezone.utc
                    )

                    - timedelta(
                        days=random.randint(
                            0,
                            29
                        ),

                        seconds=random.randint(
                            0,
                            86399
                        )
                    )
                )


                orders.append(
                    (
                        order_id,
                        user_id,
                        restaurant_id,
                        amount,
                        status,
                        created_at
                    )
                )


            # Update wallets.
            # Trigger creates audit rows.

            for amount, user_id in wallet_updates:

                cursor.execute(

                    """
                    UPDATE users

                    SET wallet_balance =
                        wallet_balance - %s

                    WHERE id = %s
                    """,

                    (
                        amount,
                        user_id
                    )
                )


            # Insert orders.

            execute_values(

                cursor,

                """
                INSERT INTO orders (
                    id,
                    user_id,
                    restaurant_id,
                    total_amount,
                    status,
                    created_at
                )

                VALUES %s
                """,

                orders
            )


            inserted_orders += current_batch


            if (
                inserted_orders
                % (batch_size * 5)
                == 0
                or inserted_orders
                == orders_count
            ):

                print(
                    f"Orders inserted: "
                    f"{inserted_orders:,}/"
                    f"{orders_count:,}"
                )


        connection.commit()


        # =================================================
        # MATERIALIZED VIEW
        # =================================================

        cursor.execute(
            """
            REFRESH MATERIALIZED VIEW
            restaurant_order_summary
            """
        )

        connection.commit()


        # =================================================
        # STATISTICS
        # =================================================

        cursor.execute(
            "SELECT COUNT(*) FROM users"
        )

        total_users = cursor.fetchone()[0]


        cursor.execute(
            "SELECT COUNT(*) FROM restaurants"
        )

        total_restaurants = cursor.fetchone()[0]


        cursor.execute(
            "SELECT COUNT(*) FROM orders"
        )

        total_orders = cursor.fetchone()[0]


        cursor.execute(
            "SELECT COUNT(*) FROM wallet_audit_logs"
        )

        total_audits = cursor.fetchone()[0]


        print()
        print("==============================")
        print("POSTGRESQL SEEDING COMPLETE")
        print("==============================")
        print(
            f"Users:         {total_users:,}"
        )
        print(
            f"Restaurants:   {total_restaurants:,}"
        )
        print(
            f"Orders:        {total_orders:,}"
        )
        print(
            f"Audit logs:    {total_audits:,}"
        )


        cursor.close()


    except Exception:

        connection.rollback()

        raise


    finally:

        connection.close()


def main():

    parser = argparse.ArgumentParser(
        description=
        "Generate BiteStream PostgreSQL data"
    )


    parser.add_argument(
        "--users",
        type=int,
        default=10000
    )


    parser.add_argument(
        "--restaurants",
        type=int,
        default=500
    )


    parser.add_argument(
        "--orders",
        type=int,
        default=120000
    )


    parser.add_argument(
        "--batch-size",
        type=int,
        default=2000
    )


    parser.add_argument(
        "--seed",
        type=int,
        default=42
    )


    args = parser.parse_args()


    seed_database(

        users_count=args.users,

        restaurants_count=args.restaurants,

        orders_count=args.orders,

        batch_size=args.batch_size,

        random_seed=args.seed
    )


if __name__ == "__main__":
    main()