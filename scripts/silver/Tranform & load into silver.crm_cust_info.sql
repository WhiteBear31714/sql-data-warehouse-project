-- Tranform & load into silver.crm_cust_info

PRINT '>> Truncating Table: silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;
PRINT '>> Inserting Data Into: silver.crm_cust_info'

INSERT INTO silver.crm_cust_info (
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_marital_status,
	cst_gndr,
	cst_create_date
)

SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname)	AS cst_firstname,-- เครียร์เว่นวรรค ชื่อจริง
	TRIM(cst_lastname)	AS cst_lastname,-- เครียร์เว่นวรรค นาสกุล
	CASE  WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'-- สร้างเคสที่ UPPER(TRIM(cst_marital_status)) = F,M => Female,Male
		  WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Maried'
		  ELSE 'n/a'
	END cst_marital_status,
	CASE  WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'-- สร้างเคสที่ UPPER(TRIM(cst_gndr)) = F,M => Female,Male
		  WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		  ELSE 'n/a'
	END cst_gndr,
	cst_create_date

FROM(
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last -- จัดลำดับแถว (Rank) ให้กับข้อมูลที่มี cst_id ซ้ำกัน" เพื่อใช้คัดเลือกเอาเฉพาะข้อมูลชุดล่าสุด
	FROM bronze.crm_cust_info
	WHERE cst_id IS NOT NULL
)t -- 't' คือการตั้งชื่อ Alias ให้ตารางเสมือนชั้นในนี้ 
WHERE flag_last = 1 