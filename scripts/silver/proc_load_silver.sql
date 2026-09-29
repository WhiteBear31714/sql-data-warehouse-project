/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

EXEC silver.load_silver

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME; 
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

	-- Tranform & load into silver.crm_cust_info
	SET @start_time = GETDATE();
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
	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
	PRINT '>> -------------';

	-- Transform & Load into silver.crm_prd_info
	SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT '>> Inserting Data Into: silver.crm_prd_info'

	INSERT INTO silver.crm_prd_info (
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)

	SELECT 
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1 , 5), '-', '_') AS cat_id,-- "REPLACE ค้นหาและแทนที่ข้อความ '-', '_'"
		SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,-- "SUBSTRING ตัดข้อความ" / prd_key, 7 ให้เริ่มตั้งแต่ตัวที่ 7 / LEN(prd_key) ความยาวรวมทั้งหมดของข้อความนั้น
		prd_nm,
		ISNULL (prd_cost, 0) AS prd_cost,-- แทน n/a เป็น 0 
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_line,
		CAST (prd_start_dt AS DATE) AS prd_start_dt,-- "CAST(... AS DATE) แปลง string วันที่ เป็น DATE"
		-- ERROR: CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
		DATEADD(day, -1, CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE)) AS prd_end_dt-- DATEADD(day, -1, ...) นำวันที่ของล็อตถัดไปมา ลบออก 1 วัน เพื่อให้เป็นวันจบของล็อตปัจจุบัน (ป้องกันช่วงเวลาทับซ้อนกัน)

	FROM bronze.crm_prd_info
    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Transform & Load into silver.crm_sales_details
	SET @start_time = GETDATE();
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
	SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Transform & Load into silver.erp_cust_az12
	SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT '>> Inserting Data Into: silver.erp_cust_az12'

	INSERT INTO silver.erp_cust_az12(
		cid,
		bdate,
		gen
	)

	SELECT
		CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, len(cid))-- ตัด NAS
			 ELSE cid
		END AS cid,
	-- ใช้ TRY_CAST หรือ TRY_CONVERT เพื่อป้องกัน Error Out-of-range
		CASE 
			WHEN TRY_CAST(bdate AS DATE) > GETDATE() THEN NULL -- ถ้าเป็นวันที่ในอนาคต เปลี่ยนเป็น NULL
			ELSE TRY_CAST(bdate AS DATE) -- ถ้าแปลงผ่านและไม่อยู่ในอนาคต ใช้ค่านั้น
		END AS bdate,-- Set future birthdates to NULL
		CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
			 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
			 ELSE 'n/a'
		END AS gen -- Noemalize gender values and handle unknown cases
	FROM bronze.erp_cust_az12

	-- Transform & Load into silver.erp_loc_a101

	PRINT '>> Truncating Table: silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT '>> Inserting Data Into: silver.erp_loc_a101'

	INSERT INTO silver.erp_loc_a101(
		cid,
		cntry
	)

	SELECT 
		REPLACE(cid, '-', '') cid, -- ลบสัญลักษณ์ '-' ให้เป็นค่าว่าง 
		CASE WHEN TRIM(cntry) = 'DE' THEN 'Gerney'
			 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
			 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		END AS cntry
	FROM bronze.erp_loc_a101
    SET @end_time = GETDATE();
    PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

	-- Transform & Load into silver.erp_px_cat_g1v2

	SET @start_time = GETDATE();
	PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2 (
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM bronze.erp_px_cat_g1v2;
	SET @end_time = GETDATE();
	PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
    PRINT '>> -------------';

    SET @batch_end_time = GETDATE();
	PRINT '=========================================='
	PRINT 'Loading Silver Layer is Completed';
    PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
	PRINT '=========================================='

		END TRY
	BEGIN CATCH
		PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END
GO
