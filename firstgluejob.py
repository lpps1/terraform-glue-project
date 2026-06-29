import sys
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, monotonically_increasing_id

# Job init
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# ================================
# READ CSV (no header)
# ================================
df = spark.read.option("header", "false") \
    .csv("s3://lal-sales-raw-2026/daily/")

# Add row index
df = df.withColumn("row_id", monotonically_increasing_id())

# ================================
# GET HEADER ROW (row 2)
# ================================
header_row = df.orderBy("row_id").limit(2).collect()[1]

# Extract header safely
header = []
for i in range(len(header_row) - 1):  # exclude row_id
    val = header_row[i]
    if val is None or val == "":
        header.append(f"col_{i}")
    else:
        header.append(val.strip())

# ================================
# REMOVE FIRST 2 ROWS
# ================================
df_clean = df.orderBy("row_id").filter(col("row_id") > 1)

# Drop row_id
df_clean = df_clean.drop("row_id")

# Rename columns
df_clean = df_clean.toDF(*header)

# ================================
# TYPE CASTING
# ================================
df_clean = df_clean.withColumn("amount", col("amount").cast("double"))
df_clean = df_clean.withColumn("order_date", col("order_date").cast("date"))

# ================================
# VERIFY
# ================================
df_clean.printSchema()
df_clean.show()

df_clean = df_clean.select(
    "order_id",
    "customer_name",
    "region",
    "amount",
    "order_date"
)
# ================================
# WRITE PARQUET
# ================================
df_clean.write \
    .mode("overwrite") \
    .partitionBy("region") \
    .parquet("s3://lal-sales-processed-terraform-2026/output/")

job.commit()