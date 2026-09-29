-- Transform & Load into silver.crm_sales_details

PRINT '>> Truncating Table: silver.crm_sales_details';
TRUNCATE TABLE silver.crm_sales_details;
PRINT '>> Inserting Data Into: silver.crm_sales_details'

INSERT INTO silver.crm_sales_details(
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
)
SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) -- แปลงข้อมูล sls_order_dt จาก INT -> VARCHER -> DATE
	END AS sls_order_dt,
	CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
	END AS sls_ship_dt,
	CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
		ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 

-- Check Data Consistency: Between Sales, Quantity, and Price 
-- >> Sales = Quantity * Price
-- >> Values must not be NULL,Zero, OR Nagarive
	END AS sls_due_dt,
	CASE WHEN sls_sales IS NULL OR sls_sales <=0 
		OR sls_sales != sls_quantity * ABS(sls_price) -- ABS() (Absolute) จะแปลงค่าติดลบให้กลายเป็นบวกก่อนนำไปคูณ ยอดขายรวมที่คำนวณได้จึงออกมาเป็นบวกเสมอ
			THEN sls_quantity * ABS(sls_price) -- แปลงค่า - เป็น + และนำไป * เพื่อได้ sls_sales
		ELSE sls_sales
	END AS sls_sales,
	sls_quantity,
	CASE WHEN sls_price IS NULL OR sls_sales <=0 
			THEN sls_sales / NULLIF(sls_quantity, 0) -- แปลงค่า sls_quantity = 0 ก่อนนำไปคำนวน 
		ELSE sls_price
	END AS sls_price
FROM bronze.crm_sales_details


