print("ingest.py started...")

from pathlib import Path
    # importing the Path class from the pathlib module (python module for working with file and directory paths)

from datetime import datetime
    # importing the datetime class from the datetime module (for working with dates and times)

import logging
    # logging module is used to record the events occuring when the program runs (unlike print command, logging writes to log files for later verification)

import duckdb
    # to communicate with DuckDB

print("modules imported...")

# ================ Configuration =========================

BASE_DIR = Path(__file__).resolve().parent
    # defines the base directory - here, the Project folder since this file is stored directly in it
    # (__file__) contains location of the current python file
    # .resolve() returns the absolute path
    # .parent returns the directory in which the current python file resides

RAW_DATA_DIR = BASE_DIR/"data"/"raw"
    # creates a path to the raw data files

DB_PATH = BASE_DIR/"MSME_EWS.duckdb"
    # defines where the DuckDB database files will be stored and what the database will be called

LOG_DIR = BASE_DIR/"logs"
    # defines where the log files will be stored

LOG_DIR.mkdir(exist_ok=True)
DB_PATH.parent.mkdir(exist_ok=True)
    # creates the log and database directories if they don't exist, and does nothing if they already exist

FILES = {
    "customers.csv":"raw_customers",
    "loans.csv":"raw_loans",
    "repayment_transactions.csv":"raw_repayment_transactions",
    "banking_behavior.csv":"raw_loan_monthly_snapshot",
    "bureau_snapshots.csv":"raw_monthly_bureau_snapshot",
}
    # creates a python dictionary with key-value pairs
    # where the key is the csv file name and the value is the DuckDB table name
    # easier to loop throught the dictionary to load files instead of running separate codes for each file

print("configuration completed...")

# ==================== Logging =========================

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    # creates a timestamp to be used in the log filename
    # datetime.now() returns the current date and time
    # .strftime() converts the datetime into a formatted string
    # where %Y%m%d_%H%M%S is the format - YYYYMMDD_HHMMSS

logging.basicConfig(
    # starts configuring the logging system
    level=logging.INFO,
        # tells python what level of messages should be recorded
        # INFO = normal pipeline activity
        # DEBUG = detailed diagnostic information
        # WARNING = something unusual but the pipeline can continue
        # ERROR = something failed
        # CRITICAL = very serious failure
        # logging.INFO tells the system to record INFO and anything more serious than INFO, i.e WARNING, ERROR, CRITICAL but not DEBUG
    format="%(asctime)s|%(levelname)s|%(message)s",
        # controls how each log message would look like
        # %(asctime) = date and time when the log was created
        # %(levelname)s = log level, eg. INFO, ERROR etc
        # %(message)s = the actual message to be displayed
    handlers = [
        logging.FileHandler(
            # tells python to send the log messages to a file
            LOG_DIR/f"ingestion_{timestamp}.log"
        ),
            # specifies the file in which to write into
            # all files will be named as "ingestion_<timestamp of particular file>.log"
        logging.StreamHandler()
            # additionally sends the log messages to the terminal screen while the pipeline is running
    ]
)

logger=logging.getLogger(__name__)
    # creates a logger object that will be called later with the commands suchs as logger.info() and logger.error()
    # logger object allows us to write messages by calling the aforementioned functions
    # __name__ = specialized python variable containing the name of the current python module/file
    # i.e. when the current file is run as the main program, the variable "__name__" becomes "__main__"
    # hence, when this file is run, a logger handle is created for the file and is stored in the variable "logger"
    # so the rest of the pipeline can write log messages using the variable

print("logging configured...")

# =================== Connect to DuckDB =======================

def create_connection():
    # defines a function called "create_connection()" to create a DuckDB connection

    logger.info("Connecting to DuckDB...")
        # writes an informational message to the log
        # since both FileHandler and StreamHandler were configured, the message is both written into log file and displayed in terminal

    con = duckdb.connect(str(DB_PATH))
        # connects python to DuckDB
        # duckdb.connect() = opens a connection to the DuckDB database
        # DB_PATH = defined earlier as the path the database file (is an object of the Path class)
        # str(DB_PATH) converts the object into a string
        # con = connection returned by DuckDB is stored in the variable "con"
        # The variable "con" can be used later to call functions such as con.execute(), con.commit, con.close() etc.

    logger.info(
        f"Connected to {DB_PATH}"
    )
        # logs the message provided
        # f"" = tell python that this is an f-string
        # f-string lets python evaluate anything within the {}, here - the DB_PATH

    return con
        # returns the DuckDB connection as the output of the create_connection() function.

print("create_connection defined...")

# ================ Create Raw Schema =================

def create_raw_schema(con):
    # defines the create_raw_schema() function that accepts the DuckDB connection "con" and creates a schema

    logger.info("Creating RAW Schema...")
        # writes the message provided to the log

    con.execute("""CREATE SCHEMA IF NOT EXISTS raw;""")
        # uses the DuckDB connection in "con" to connect to DuckDB and execute the statement provided
        # .execute() = sends a SQL command to DuckDB
        # """ = triple quotes allow to write a multi-line string - here, SQL code

    logger.info("RAW schema ready.")
        # writes log message

print("create_raw_schema defined...")

# ================== Validate Files ================

def validate_files():
    # defines a function to validate if the raw data files exist before we try to load them into tables

    logger.info("Checking required input files...")
        # writes log message

    missing_files=[]
        # creates an empty python list called "missing_files"

    for filename in FILES:
        # starts a for loop within the FILES dictionary defined above as containing all the csv filenames and corresponding table names
        # filename = temporary variable storing the current csv file name during each iteration

        file_path = RAW_DATA_DIR/filename
            # creates a full path to the current csv file based on the variable filename for the current iteration

        if not file_path.exists():
            # checks whether the file in the "file_path" actually exists
            # .exists() = returns True if the file/path exsits and False if it doesn't
            # if not = executes the followng code if the file/path does NOT exist

            missing_files.append(filename)
                # adds the name of the current csv file into the missing files list
                # .append() = add one item to the end of the list

            logger.error(
                f"Missing file: {filename}"
            )
                # writes an ERROR level message into the log

        elif not file_path.is_file():
            # else-if condition statement - if the file/path exists, this condition is checked
            # the condition = whether the file in the "file_path" points to an actual file
            # elif not = executes the following code if the file/path does NOT point to an actual file

            missing_files.append(filename)
                # adds the name of the current csv file to the missing files list

            logger.error(
                f"Not a valid file: {filename}"
            )
                # writes an ERROR level log message

        else:
            # when neither of the previous conditions was true,
            # i.e. the file/path is valid and the file is actually a valid file

            logger.info(
                f"Found: {filename}"
            )
                # write an INFO message into the log

    if missing_files:
        # checks whether the "missing_files" list contains any items
        # returns True if any item present in the list
        # returns False if list is empty

        raise FileNotFoundError(
            f"Missing files: {missing_files}"
        )
            # stops the pipeline and raises an error because required files are missing
            # raise = generate an exception immediately
            # FileNotFoundError() = python exception specifically used when something expected is not found
            # prevents further execution if any of the raw data files are missing

    logger.info(
        "All required files are present"
    )
        # executed only when the missing_files list is empty, and writes a successful log entry

print("validate_files defined...")

# ===================== Validate CSV ======================

def validate_csv(con, file_path):
    # defines the function validate_csv() to check whether the files have any data or are empty
    # con = the DuckDB connection
    # file_path = the path to the csv file being checked

    logger.info(
        f"Validating {file_path.name}"
    )
        # writes log message
        # .name = extracts only the name from the full file path

    # Reading only first few rows to validate

    result = con.execute(
        """
        SELECT *
        FROM read_csv_auto(?)
        LIMIT 10;
        """,
        [str(file_path)]
    )
        # executes the SQL code in DuckDB using the connection in "con"
        # returns the result of the query into the variable "result"
        # read_csv_auto(?) = DuckDB function to read CSV files
        # where the auto allows DuckDB to automatically determine column names, data types, csv structure etc
        # (?) = the ? is a placeholder for the filename (? = one item)
        # filename is specified as the second input of the execute function - [str(file_path)]

    rows = result.fetchall()
        # retrieves all the rows returned by DuckDB into the variable "result"

    if not rows:
        # if the rows variable is empty, executes the following command

        raise ValueError(
            f"{file_path.name} contains no data."
        )
            # stops the pipeline and raises an error because required files are empty
            # raise = generate an exception immediately
            # ValueError() = file exists and DuckDB can read it but the content of the file is invalid
            # prevents further execution if any of the raw data files are empty

    logger.info(
        f"{file_path.name} passed validation."
    )
        # if files are not empty, success message written into log

print("validate_csv defined...")

# ====================== Load CSV onto Raw Tables ============================

def load_csv(con, filename, table_name):
    # defines load_csv() function to load the csv files onto DuckDB tables
    # con = DuckDB connection
    # filename = csv file name
    # table_name = destination table name

    file_path = RAW_DATA_DIR/filename
        # returns the full path of the file into the file_path variable

    logger.info(
        f"Loading {filename} -> raw.{table_name}"
    )
        # writes a log message describing the "filename" being loaded onto the "table_name"

    # DuckDB reads the CSV directly, hence -

    con.execute(
        f"""
        CREATE OR REPLACE TABLE raw.{table_name} AS
        SELECT *
        FROM read_csv_auto(?);
        """,
        [str(file_path)]
    )
        # CTAS table creation from the filename into the corresponding table_name as defined in the FILES dictionary
        # CREATE OR REPLACE = ensures idempotency in the script

    # Count rows

    row_count = con.execute(
        f"""
        SELECT COUNT(*)
        FROM raw.{table_name};
        """
    ).fetchone()[0]
        # returns the number of all loaded rows
        # .execute runs the SQL query in DuckDB using con, resulting in the aggregated count row
        # .fetchone() fetches the first row (only row)
        # .fetchone()[0] fetches the first value from that row

    logger.info(
        f"Loaded {row_count:,} rows"
        f"into raw.{table_name}"
    )
        # writes log message
        # row_count:, = The ":," tells python to display the number with thousands separators (commas)

    return row_count
        # returns the row_count as the output for the load_csv() function

print("load_csv defined...")

# ================= Verify Load ====================

def verify_load(con, table_name, expected_rows):
    # defines verfiy_load() function

    actual_rows = con.execute(
        f"""
        SELECT COUNT(*)
        FROM raw.{table_name};
        """
    ).fetchone()[0]
        # determines the actual count of rows loaded onto the table "table_name"

    if actual_rows != expected_rows:
        # if the number of actual rows don't match the expected number of rows, executes the next code block

        raise ValueError(
            f"Row count mismatch for "
            f"raw.{table_name}:"
            f"expected {expected_rows},"
            f"found {actual_rows}"
        )
            # stops the pipeline and raises an error because of row count mismatch
            # raise = generate an exception immediately
            # ValueError() = value is inappropriate or doesn't meet an expected condition
            # prevents further execution in case of mismatch in the actual and expected number of rows

    logger.info(
        f"Verified raw.{table_name}:"
        f"{actual_rows:,} rows"
    )
        # if there isn't any mismatch, writes into the log

print("verify_load defined...")

# ============================ Run Pipeline =============================

def run_pipeline():
    # defines the run_pipeline() function

    start_time = datetime.now()
        # records the exact date and time when the pipeline started and stores it in start_time variable

    logger.info("="*60)
    logger.info("MSME EWS INGESTION STARTED")
    logger.info("="*60)
        # writes into log
        # "="*60 -> this outputs the "=" characted 60 times

    con = None
        # creates the variable "con" and sets it to None (as it is not connected to DuckDB yet)

    try:
        # starts python's exception handling block -
        # try: = code to be run and might fail
        # except Exception: = what to do if code fails
        # finally: cleanup after the exception handling
        # Here, all the functions defined above are called (might fail, hence exception handling)

        # Validate the data files (check whether the files are present and valid)
        validate_files()

        # Connect to DuckDB
        con = create_connection()

        # Create Raw Schema using the DuckDB connection stored in "con"
        create_raw_schema(con)

        # Validate CSV files (check whether files are empty)
        for filename in FILES:
            # loop through the FILES dictionary
            # could also be written as -> for filename in FILES.keys():

            file_path = RAW_DATA_DIR/filename

            validate_csv(con, file_path)

        # Load files
        for filename, table_name in FILES.items():
            # loops through the FILES dictionary again, but
            # .items() = returns both sides of the key-value pair
            # hence, here the function returns both the filename and corresponding table_name

            rows_loaded = load_csv(con, filename, table_name)
                # load_csv() loads the csv file "filename" onto table "table_name", and returns the total row count for the table
                # since load_csv() returns the total rwo count, that is now stored in rows_loaded variable

        # Verify load
        verify_load(con, table_name, rows_loaded)
            # verfiy_load takes con, table name and the expected number of rows in the table as the input
            # here, the rows_loaded in the load_csv() function are the expected rows
            # hence this function verifies whether the load_csv() function loaded the rows correctly

        # Commit
        con.commit()
            # during the pipeline, changes are made to DuckDB database such as creating schema and loading data
            # .commit() = commits the changes made through this database connection

        duration = datetime.now() - start_time
            # calculates the duration it took for the pipeline to execute,
            # by subtracting the starting timestamp from current timestamp

        logger.info("="*60)
        logger.info(
            f"MSME EWS INGESTION COMPLETED SUCCESSFULLY"
        )
        logger.info(
            f"Duration: {duration}"
        )
        logger.info("="*60)
            # writes log message

    except Exception:
        # if any exception occurs in the "try:" block, the following code block is executed
        # Exception = python's general class for many normal runtime errors
        # in this file, we have defined the errors using FileNotFoundError and ValueError exceptions and raise command

        logger.exception(
            "INGESTION PIPELINE FAILED"
        )
            # writes the exception error message into log

        raise
            # different from raise Exception()
            # the bare raise simply propogates the Exception encountered in the try block, 
            # and returns the original error as output to the run_pipeline() function

    finally:
        # runs at the end of the try block, regardless of whether the try block succeeds or fails (exception)
        # purpose is cleanup

        if con:
            # con was initially set to None, then create_connection() assigned a DuckDB connection to con
            # if con: = returns True if con has been assigned a value

            con.close()
                # closes the DuckDB connection

            logger.info(
                "DuckDB connection closed"
            )
                # writes into log

print("run_pipeline defined...")

# ===================== Main ===========================

if __name__ == "__main__":
    # when the current file "ingest.py" is run, python sets the "__name__" as "__main__"
    # hence, this condition becomes True as soon as the file is run 

    run_pipeline()