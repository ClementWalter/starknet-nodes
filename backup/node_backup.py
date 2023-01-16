import logging
import shutil
import sqlite3
from pathlib import Path

import boto3

logging.basicConfig()
logger = logging.getLogger("node_backup")
logger.setLevel(logging.INFO)
s3 = boto3.resource("s3")

BUCKET_NAME = "pathfinder-starknet-node-backup"
DATA_DIR = Path("data")
BACKUP_DIR = Path("backup")
DB_PATH_PATTERN = str(Path("{db}") / "{db}.sqlite")


def progress(db):
    def _progress(status, remaining, total):
        if (total - remaining) % 100 == 0:
            logger.info(f"Status {status}; Db {db}; copied {total-remaining}/{total}")

    return _progress


for db in ["goerli", "mainnet", "testnet2"]:
    db_path = DB_PATH_PATTERN.format(db=db)
    con = sqlite3.connect(DATA_DIR / db_path)
    (BACKUP_DIR / db_path).parent.mkdir(parents=True, exist_ok=True)
    bck = sqlite3.connect(BACKUP_DIR / db_path)
    with bck:
        con.backup(bck, progress=progress(db))
    bck.close()
    con.close()
    s3.meta.client.upload_file(str(BACKUP_DIR / db_path), BUCKET_NAME, db_path)
    logger.info(f"Db: {db} uploaded to s3 {BUCKET_NAME}")

shutil.rmtree(BACKUP_DIR, ignore_errors=True)
