import os
import pymysql
from contextlib import contextmanager

DATABASE_URL = os.environ["DATABASE_URL"]
DATABASE_PORT = int(os.environ["DATABASE_PORT"])
DATABASE_USER = os.environ["DATABASE_USER"]
DATABASE_NAME = os.environ["DATABASE_NAME"]
DATABASE_PASSWORD = os.environ["DATABASE_PASSWORD"]


@contextmanager
def table(conn):
    sql = "create temporary table foo (id int not null primary key auto_increment, value varchar(255) not null)"
    with conn:
        with conn.cursor() as cursor:
            cursor.execute(sql)
            yield cursor


def handler(event, context):
    conn = pymysql.connect(
        host=DATABASE_URL,
        user=DATABASE_USER,
        database=DATABASE_NAME,
        password=DATABASE_PASSWORD,
        port=DATABASE_PORT,
    )

    with table(conn) as cursor:
        cursor.execute("insert into foo (value) values (%s)", "test")
        cursor.execute("insert into foo (value) values (%s)", "another")

        rows = []
        cursor.execute("select * from foo")
        for row in cursor.fetchall():
            rows.append(row)

    return {"results": rows}
